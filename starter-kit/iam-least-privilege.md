# Least privilege model
- We will define an IAM Role specifically for the backend instance running the reconciliation logic. This role will have a scoped-down policy that only allows access to the finance-reports bucket

## The JSON Policy (The "Permissions")
This policy allows the application to list the bucket and download files, but explicitly forbids DeleteObject or PutObject (to prevent tampering with raw logs).
 ```
JSON
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowListBucket",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::kijanikiosk-finance-reports"
        },
        {
            "Sid": "AllowReadObjects",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::kijanikiosk-finance-reports/*"
        }
    ]
}
```

## Why this design works for KijaniKiosk
- **Blast Radius Reduction**: If the backend is ever compromised, the attacker cannot delete your historical financial records.

- **Auditability**: Every time the application assumes this role to read a file, it is logged in AWS CloudTrail, giving the DevOps team a clear audit trail of who accessed financial data.

- **Regional Reliability**: Since S3 is a regional service, this policy works seamlessly across all Availability Zones in the Cape Town region without modification