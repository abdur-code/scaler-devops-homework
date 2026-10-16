# 08 - Terraform destroy

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

`terraform destroy` removes everything the current state manages. Internally it is a
plan in destroy mode, followed by an approval, followed by the deletions.

`main.tf` is the lecture file (resource `aws_s3_bucket.destroy_demo`) with my bucket
prefix `abdur-24bcs10244-s18-08-destroy-` and `default_tags`.

## Setup (added: the notes start at "Before Destroy")

The notes go straight to `terraform state list` and expect a resource to be there, but
nothing in this folder had been created yet. I added `init` and `apply` first so there was
something to destroy:

```bash
terraform init
terraform apply
yes
```

![init](screenshots/01-init-added_24BCS10244.png)
![apply](screenshots/02-apply-added_24BCS10244.png)

One bucket created: `abdur-24bcs10244-s18-08-destroy-0669c91ba2201c43c6edf0a171`.

## Before destroy

```bash
terraform state list
grep -n '^resource' main.tf
```

![state list](screenshots/03-state-list_24BCS10244.png)

### Problem found: the README uses the wrong resource name

The notes expect `aws_s3_bucket.lifecycle_demo` (here and in every destroy example), but
the state shows `aws_s3_bucket.destroy_demo`.

The root cause is that the README text was copied from folder 07, whose resource is
called `lifecycle_demo`, while this folder's `main.tf` (line 26) names it `destroy_demo`.
The code is fine and the README is wrong, so no code change was needed. I used the real
address everywhere below. If I had copied `terraform state show aws_s3_bucket.lifecycle_demo`
from the notes, it would fail with "No instance found for the given address"
(the same error is shown in the
[S3 demo](../terraform-s3-demo/README.md#problem-found-the-readme-uses-a-resource-name-that-doesnt-exist)).

## Inspect the destroy plan first

The notes say to always run `terraform plan -destroy` before `terraform destroy`.

```bash
terraform plan -destroy
```

![plan -destroy](screenshots/04-plan-destroy_24BCS10244.png)

`# aws_s3_bucket.destroy_demo will be destroyed`, every attribute going `-> null`, and
`Plan: 0 to add, 0 to change, 1 to destroy.` Nothing is deleted yet. This is the step to
review, and the step to stop at if the list contains something unexpected.

## Destroy

```bash
terraform destroy
yes
terraform state list
```

![destroy](screenshots/05-destroy_24BCS10244.png)

Terraform printed the same destroy plan, asked "Do you really want to destroy all
resources? There is no undo.", and after `yes`:
`aws_s3_bucket.destroy_demo: Destroying...`, `Destruction complete after 1s`,
`Destroy complete! Resources: 1 destroyed.` The empty `state list` confirms Terraform
manages nothing here anymore.

## Practice questions

1. What is the difference between `plan` and `apply`? `plan` only computes and shows the
   changes and never modifies anything. `apply` computes the same plan (or uses a saved
   one) and then executes it against AWS.
2. What does `destroy` do? It plans the deletion of every resource in the current state
   (dependencies in reverse order), asks for confirmation and deletes them. It only
   touches what is in this state, and other resources in the account are not affected.
3. Why run `plan -destroy` before deleting production infrastructure? `destroy` is
   irreversible, because a deleted database or bucket is gone. `plan -destroy` shows
   exactly what would be deleted, so a wrong workspace, a wrong state file or an
   unexpectedly large resource list is caught before anything happens. The plan can also
   be saved (`plan -destroy -out=…`) and reviewed by someone else.

## What I understood

- Destroy is a plan where the desired state is "nothing".
- The resource address in the README has to match the code, and `terraform state list`
  is a quick way to see the real addresses.
- An S3 bucket can only be deleted when it is empty. These buckets were empty, so the
  destroy took about a second. For buckets with objects, Terraform needs
  `force_destroy = true` (the S3 demo uses it).
