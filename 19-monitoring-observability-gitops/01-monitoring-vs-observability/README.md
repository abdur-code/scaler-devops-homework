# Monitoring vs Observability

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

Homework Task 2 (observability documentation). This part of the lecture has no commands,
so this README is the write-up. Where I can, I point to what I actually saw in the demos
of this session.

## Monitoring vs observability

**Monitoring** watches signals you already decided were important and tells you when one
crosses a line: CPU above 80 %, error rate above 5 %, a target that stopped answering. It
answers *"is something wrong?"*. In this session the `TargetDown` alert in
[`03-prometheus`](../03-prometheus/README.md#addition-an-alerting-rule-that-fires) is
monitoring: one rule, one condition, a clear yes/no.

**Observability** is a property of the system: how much the data it emits lets you work
out *why* it is behaving the way it is, including for problems nobody predicted. A
monitored system can tell you "latency is 2 s". An observable one lets you follow a slow
request and find that 1.2 s of it was spent in the database.

| | Monitoring | Observability |
|---|---|---|
| Question | Is it healthy? | Why is it behaving like this? |
| Problems | known failure modes | unknown / new failure modes |
| Typical output | dashboards, alerts | metrics + logs + traces you can query and correlate |
| Example from this session | `up == 0` for 30 s → alert fires | reading the Pod's events found *why* the new Pod never became Ready: `connect: connection refused` on 8080 |

The two are not alternatives. Monitoring is what wakes you up, and observability is what
lets you fix the problem once you are awake.

## The three pillars

| Pillar | What it is | Answers | What I used in this session |
|---|---|---|---|
| **Metrics** | numbers sampled over time, each with a name and labels | how much / how often | Prometheus: `up`, `process_cpu_seconds_total`, `process_resident_memory_bytes`, `prometheus_http_requests_total`; `kubectl top` |
| **Logs** | timestamped text events written by a program | what happened | `kubectl logs deployment/session20-demo`, the nginx access log of the 05 app |
| **Traces** | the path of one request through several services, split into timed spans | where the time went | not run (no traced app in the lecture); explained below |

**Metrics** are cheap to store because each one is just a number per scrape, so you can
keep them for a long time and alert on them. Labels (`job`, `instance`, `handler`,
`code`) let one metric name cover many series. In 03, `prometheus_http_requests_total`
had a separate counter for every handler and status code. A counter only goes up, so the
useful question is how fast it grows. That is why the CPU query is
`rate(process_cpu_seconds_total[1m])` and not the raw value.

**Logs** carry detail that a number can't: which user, which order id, which error
message. The cost is volume, and logs are hard to aggregate unless they are structured
(JSON, key=value). In Kubernetes a container's stdout/stderr *is* its log, which is why
`kubectl logs` works without any setup. The lines disappear with the Pod unless something
ships them elsewhere.

**Traces** follow a single request. The first service creates a trace id and passes it
on in a header (`traceparent` in W3C Trace Context). Every service the request touches
records a *span* with its start time, duration and the trace id. Put together, the spans
form the tree the lecture draws:

```text
trace 4bf92f35…   total 820 ms
└─ api-gateway            20 ms
   └─ order-service       80 ms
      ├─ payment-service 120 ms
      └─ database        600 ms   ← the slow part
```

Metrics would only show that p99 latency went up, and logs would show three services each
logging their own part. The trace is the only one that shows where the time went for a
single request. Traces need the app to be instrumented (usually with OpenTelemetry), which
is why the busybox and nginx demos here can't produce them.

The three pillars work best when they are linked: an alert on a metric points to the
time window, the logs in that window give the error, and a trace id in the log line opens
the exact slow request.

## Why observability is needed

- **Systems are distributed.** One user click can touch a gateway, five services, a queue
  and two databases, often on different nodes. No single machine's dashboard shows the
  whole picture.
- **Failures are new each time.** You can only write alerts for failures you already know
  about. Observability is for the ones you don't, so you can ask new questions of the data
  without shipping new code first.
- **Kubernetes keeps moving things.** Pods are rescheduled, scaled and replaced, and their
  IPs and names change. Data has to be labelled by app and namespace, not by machine,
  and collected before the Pod is gone.
- **"Running" is not "working".** In 02 the Pod was `Running` and `1/1 Ready` while every
  request to its Service got `connection refused`. Only by looking further (the endpoints,
  a request from inside the cluster, the probe events) did the real state show up.
- **Time to recovery.** The faster you can find the cause, the shorter the outage. That is
  what users actually notice.

## Common tools

| Job | Open-source tools | Hosted / commercial |
|---|---|---|
| Metrics collection and storage | **Prometheus**, VictoriaMetrics, Thanos / Mimir (long-term) | CloudWatch, Datadog, Grafana Cloud |
| Dashboards | **Grafana** | Datadog, New Relic |
| Alert routing | Prometheus **Alertmanager** | PagerDuty, Opsgenie |
| Log shipping | Fluent Bit, Fluentd, Promtail, Vector | CloudWatch Logs agent |
| Log storage and search | Loki, Elasticsearch / OpenSearch (+ Kibana) | Splunk, Datadog Logs |
| Tracing | Jaeger, Grafana Tempo, Zipkin | AWS X-Ray, Honeycomb |
| Instrumentation standard | **OpenTelemetry** (SDKs + Collector), one API for metrics, logs and traces | supported by all of the above |

## Kubernetes observability

Kubernetes is observed at three levels, and each has its own sources:

| Level | Questions | Sources |
|---|---|---|
| Cluster / nodes | Are nodes healthy, is there capacity? | `kubectl get nodes`, `kubectl top node` (metrics-server), node-exporter |
| Workloads / objects | Are Deployments at their desired replicas? Are Pods restarting? | `kubectl get/describe`, **events** (`kubectl get events`), kube-state-metrics |
| Containers / apps | CPU, memory, errors, latency of my app | kubelet/cAdvisor metrics, `kubectl top pods`, app `/metrics`, `kubectl logs`, probes, traces |

What I used or saw in this session:

- **metrics-server** behind `kubectl top pods` / `kubectl top node` (02, 05). It only keeps
  the latest value, which is enough for `top` and the HPA but has no history. For
  history you run Prometheus in the cluster, usually through the `kube-prometheus-stack`
  Helm chart (Prometheus Operator, Alertmanager, Grafana, node-exporter,
  kube-state-metrics).
- **Container logs** through the kubelet (`kubectl logs`, `--timestamps`, `--prefix`,
  `-l app=…`). In production a log agent runs as a DaemonSet on every node, reads the
  container log files and ships them to Loki or Elasticsearch, so logs survive the Pod.
- **Events**, the object-level log of the cluster. Two of the most useful findings this
  session came from events: `Readiness probe failed: … connection refused` (02) and
  Argo CD's `Initiated automated sync` right after my manual `kubectl scale` (07, 08).
- **Probes.** Liveness and readiness probes turn the application's own health into
  something Kubernetes acts on: an unready Pod is taken out of the Service's endpoints,
  and a rollout stops instead of replacing working Pods with broken ones (02).
- **Controllers that report health.** Argo CD shows `Healthy` / `Progressing` /
  `Degraded` per application, by looking at the Deployments it manages (07, 08).

## What I understood

- Monitoring answers "is it broken?" for failures I predicted. Observability is having
  enough data to answer "why?" for failures I didn't predict. A real setup needs both.
- Metrics tell me how much, logs tell me what happened, and traces tell me where the time
  went. Each one is weak alone, and they are strongest when linked through labels,
  timestamps and trace ids.
- Counters such as `process_cpu_seconds_total` only make sense as a rate. Gauges such as
  `process_resident_memory_bytes` can be read directly.
- In Kubernetes, `Running` only means the process started. Health has to be checked from
  outside the process (a probe, a request, `up`). Otherwise traffic is sent to a Pod that
  can't serve it, as in 02.
