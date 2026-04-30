terraform {
  backend "s3" {
    bucket         = "capstone-sre-tfstate-591316258137"
    key            = "phase-01/terraform.tfstate"
    region         = "us-east-1"
    # TODO (Phase 2+): Migrate to use_lockfile = true (native S3 lockfile; dynamodb_table is deprecated).
    # Current: dynamodb_table works but is pre-1.6 style. After Phase 1 stabilizes, backport:
    # use_lockfile = true  # replace the line below
    dynamodb_table = "capstone-sre-tflock"
    encrypt        = true
  }
}
