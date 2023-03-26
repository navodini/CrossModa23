#!/usr/bin/env cwl-runner
#
# Annotate an existing submission status
#

cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.4.0

inputs:
  - id: submissionid
    type: int
  - id: submission_status
    type: string
  - id: synapse_config
    type: File

arguments:
  - valueFrom: update_status.py
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.submission_status)
    prefix: --sub_status

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: update_status.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import synapseclient
          import time
          
          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          parser.add_argument("--sub_status", required=True, help="Submission status (one of VALIDATED, SCORED, INVALID)")

          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login(silent=True)

          if args.sub_status in ["VALIDATED", "SCORED"]:
            new_status = "ACCEPTED"
          else:
            new_status = "INVALID"
          
          sub = syn.getSubmissionStatus(args.submissionid)
          sub.status = new_status
          try:
            syn.store(sub)
          except synapseclient.core.exceptions.SynapseHTTPError:
            time.sleep(3)
            sub = syn.getSubmissionStatus(args.submissionid)
            sub.status = new_status
            syn.store(sub)
            

outputs:
- id: finished
  type: boolean
  outputBinding:
    outputEval: $( true )