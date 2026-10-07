# 01 - Cloud Service Models

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

Concept notes only. This part of the lecture has no commands to run, so there are no
screenshots here. The hands-on part starts in [06-terraform-vpc](../06-terraform-vpc/).

## The idea

Cloud computing means renting compute, storage and network from a provider (AWS, Azure,
Google Cloud) instead of buying and running the hardware yourself. The three service
models differ in **where the line is** between what I manage and what the provider manages.

| Model | I manage | Provider manages | AWS example |
|---|---|---|---|
| IaaS (Infrastructure as a Service) | OS, runtime, configuration, application | physical servers, virtual machines, storage, network | EC2, EBS, VPC |
| PaaS (Platform as a Service) | my application and its data | runtime, OS, servers, infrastructure | Elastic Beanstalk |
| SaaS (Software as a Service) | only how I use it and my data | everything | Gmail, Google Docs, Microsoft 365, Slack |

```text
IaaS -> more control, more responsibility
PaaS -> less infrastructure work
SaaS -> just use the software
```

The lecture's house analogy: IaaS is renting an empty house, PaaS is a furnished
apartment, SaaS is a hotel room.

## Practice: classify these

| Service | Model | Why |
|---|---|---|
| EC2 | IaaS | I get a virtual machine and install the OS-level software myself |
| Gmail | SaaS | I only use the mailbox |
| Elastic Beanstalk | PaaS | I hand over the code; AWS sets up servers, load balancer and runtime |
| Google Docs | SaaS | finished software in the browser |
| Virtual Machine | IaaS | a raw compute building block |

## Where this shows up in my homework

Everything I build with Terraform in this session is **IaaS**: a VPC, a subnet, a route
table, a security group, and in [09-final-project](../09-final-project/) an EC2 instance
where I install and configure the web server myself (through `user_data`). The S3 bucket
is somewhere in between: I don't manage any servers for it, but I still decide its name,
settings and lifetime.

## What I understood

- The three models are about who is responsible for which layer, not about which
  company sells them.
- More control (IaaS) also means more work and more ways to get it wrong, such as leaving
  SSH open or forgetting to delete a VM that keeps costing money.
- Terraform is most useful at the IaaS level, where there are many separate building
  blocks that have to be created in the right order and later removed again.
