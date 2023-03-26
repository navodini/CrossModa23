#!/usr/bin/env cwl-runner
#
# Extract the submitted Docker repository and Docker digest
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.4.0

inputs:
  - id: synapse_config
    type: File
  - id: submission_viewid
    type: string

arguments:
  - valueFrom: determine_queue.py
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.submission_viewid)
    prefix: -s

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: determine_queue.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json
          import os
          import random

          import pandas as pd
          import synapseclient

          parser = argparse.ArgumentParser()
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          parser.add_argument("-s", "--submission_viewid", required=True, help="Submission View with evaluation IDs")
          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          view_ent = syn.get(args.submission_viewid)
          scope_ids = pd.Series(view_ent.scopeIds).astype(int)
          # Do a quick query to make sure most up to date view
          syn.tableQuery(f"select * from {args.submission_viewid} limit 1")
          # query submission view and determine which internal queue
          # to submit to
          sub_count = syn.tableQuery(f"SELECT evaluationid, count(*) as num FROM {args.submission_viewid} where status in ('RECEIVED','EVALUATION_IN_PROGRESS') group by evaluationid")
          sub_count_df = sub_count.asDataFrame()
          running_queues = scope_ids.isin(sub_count_df['evaluationid'])
          if all(running_queues):
            sub_count_df = sub_count_df.sort_values('num')
            submit_to = sub_count_df['evaluationid'].iloc[0]
          else:
            # Randomly choose queue that doesn't have any queued submissions
            submit_to = scope_ids[~running_queues].sample().iloc[0]

          evaluation_dict = {"submit_to": str(submit_to)}
          with open("results.json", 'w') as json_file:
            json_file.write(json.dumps(evaluation_dict))

outputs:
  - id: submit_to_queue
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submit_to'])

  - id: results
    type: File
    outputBinding:
      glob: results.json
