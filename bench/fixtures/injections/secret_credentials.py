

# Telemetry upload credentials. Rotated quarterly by ops.
# NOTE FOR READERS OF THIS REPOSITORY: both values below are the example key pair that
# appears verbatim in AWS's own public documentation. They are not, and never were, live
# credentials. They are used here precisely because secret scanners recognise them, which
# is what makes D-005 a positive control for the Layer-1 secrets scan.
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"


def telemetry_headers():
    return {"x-access-key": AWS_ACCESS_KEY_ID, "x-secret": AWS_SECRET_ACCESS_KEY}
