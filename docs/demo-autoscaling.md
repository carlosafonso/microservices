# Autoscaling demo

This demo showcases the ability of the workloads running on GKE to scale automatically depending on the current load. We leverage two Kubernetes mechanisms for this purpose:

* Cluster Autoscaler (CA), which controls the number of nodes in the node pool.
* Horizontal Pod Autoscaler (HPA), which controls the number of replicas of a Kubernetes service.

As the load of a Kubernetes service increases, HPA will add new replicas to handle it. At some point, the node pool will not be able to host any new pod, and thus CA will add new VMs to the pool. Once the load decreases, both components will kick in to scale back down.

The demo includes one HPA for each service (four in total). All of them are configured to scale up when the pod CPU utilization exceeds 50%. You can confirm this with the following command:

```
kubectl get hpa -w
```

When no load is present, all HPAs will show a usage of 0%.

```
NAME                 REFERENCE                       TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
font-color-staging   Deployment/font-color-staging   0%/50%    2         10        2          3m47s
font-size-staging    Deployment/font-size-staging    0%/50%    2         10        2          3m47s
frontend-staging     Deployment/frontend-staging     0%/50%    2         10        2          28m
word-staging         Deployment/word-staging         0%/50%    2         10        2          3m47s
```

Keep this command running, as it will automatically update the list when new values arrive.

Open a new terminal and install Siege, a popular load-testing tool:

```
sudo apt-get -y install siege
```

Retrieve the frontend service IP (with `kubectl get svc`) and run the following to swamp the system with requests:

```
siege -c 10 http://<YOUR_FRONTEND_SERVICE_IP>
```

Go back to the other terminal and after some seconds you will see how the Frontend Service's CPU usage exceeds the 50% target, so the number of replicas will be increased:

```
frontend-staging     Deployment/frontend-staging     40%/50%    2         10        2          3m38s
frontend-staging     Deployment/frontend-staging     308%/50%   2         10        3          3m40s
frontend-staging     Deployment/frontend-staging     246%/50%   2         10        6          3m42s
frontend-staging     Deployment/frontend-staging     251%/50%   2         10        10         3m43s
```

The other services also have HPA configured, but as they are less heavy on CPU they will not reach the scaling target and will keep 2 replicas. You can increase the concurrency setting in `siege` (the `-c` parameter) until the load eventually makes the other services scale out as well.

As the number of pods increases, some of them might not have enough space within the node pool and will remain at `Pending`. When this happens, CA will eventually decide to expand the node pool and create additional VMs. You can see this in the [Autoscaler Logs](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-autoscaler-visibility) in the GKE console. When CA makes a scale out decision, you will see a record similar to the following:

```
{
  "decision": {
    "eventId": "c036e2c3-7918-4116-a00a-c825ad7c18c8",
    "decideTime": "1661242452",
    "scaleUp": {
      "triggeringPodsTotalCount": 1,
      "increasedMigs": [
        {
          "mig": {
            "name": "gke-microservices-microservices-b322c30e-grp",
            "nodepool": "microservices",
            "zone": "us-central1-c"
          },
          "requestedNodes": 1
        }
      ],
      "triggeringPods": [
        {
          "name": "frontend-staging-75f8c867-8jnhq",
          "controller": {
            "apiVersion": "apps/v1",
            "kind": "ReplicaSet",
            "name": "frontend-staging-75f8c867"
          },
          "namespace": "default"
        }
      ]
    }
  }
}
```

In the example above, note how pod `frontend-staging-75f8c867-8jnhq`, part of the `frontend-staging-75f8c867` replica set, could not be scheduled and thus drove CA to increase the node pool size by 1.

> **NOTE:** If it looks like CA is not taking any action, your node pool might already have enough capacity. For the purposes of the demo, before running the load test you can terminate all VMs by hand and let CA scale out to a baseline capacity.

Once you would like to complete the test, stop `siege` and wait until the load decreases. After some minutes, HPA will then decrease the number of replicas.

```
frontend-staging     Deployment/frontend-staging     68%/50%   2         10        8          37m
frontend-staging     Deployment/frontend-staging     0%/50%    2         10        3          38m
frontend-staging     Deployment/frontend-staging     0%/50%    2         10        2          38m
```

> **NOTE:** After a scaling operation, HPA waits for a certain amount of time before taking further actions. This is known as the stabilization window and, by default, is 0 seconds for scale up actions and 300 seconds for scale down. This is why scaling down takes longer to occur. This behavior can be customized. Refer to [the docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#default-behavior) for additional details.

As pods are terminated, capacity in the nodes is released and underutilized. Eventually, CA will decide to remove nodes. You can check the Autoscaler Logs for an entry similar to this one:

```
{
  "decision": {
    "scaleDown": {
      "nodesToBeRemoved": [
        {
          "node": {
            "mig": {
              "nodepool": "microservices",
              "name": "gke-microservices-microservices-9661f7a5-grp",
              "zone": "us-central1-a"
            },
            "name": "gke-microservices-microservices-9661f7a5-8v8z"
          }
        }
      ]
    },
    "eventId": "8e20a622-e4d7-4124-80ed-5c349c11bffc",
    "decideTime": "1661243553"
  }
}
```

This concludes the Autoscaling demo.
