# microservices

This repository contains a demo of a sample microservices-based architecture. The idea of this demo is to easily set up and play around with concepts such as CI/CD deployment techniques, service meshes, service discovery, operational dashboards, etc.

The current implementation supports Amazon ECS, but a Kubernetes version (hosted on Amazon EKS) is also in the works.

## How to deploy (Amazon ECS)

The infrastructure is defined as a set of nested CloudFormation templates. Just package and deploy the master template located in `ecs/template.yaml`. You can do this easily with the AWS CLI:

```
# Create an S3 bucket for storing the processed templates, if you don't have
# one already (otherwise you can skip this)
aws s3 mb s3://<your-bucket-name>

# Package all the templates
aws cloudformation package \
	--template-file ./ecs/template.yaml \
	--s3-bucket <your-bucket-name> \
	--output-template-file ./ecs/processed.yaml

# And now deploy them
aws cloudformation deploy \
	--stack-name microservices \
	--template-file ./ecs/processed.yaml \
	--capabilities CAPABILITY_IAM
```

Note that if you don't specify any parameters, the template will use the default images hosted in the Amazon ECR Public Gallery. But you can use your own images, even those hosted in ECR private repositories, like this:

```
aws cloudformation deploy \
	--stack-name microservices \
	--template-file ./ecs/processed.yaml \
	--parameter-overrides \
		FontColorImageUri=<URL-to-your-image> \
		FontSizeImageUri=<URL-to-your-image> \
		WordImageUri=<URL-to-your-image> \
		FrontendImageUri=<URL-to-your-image> \
	--capabilities CAPABILITY_IAM
```

The stack output includes a link to the ALB endpoint, which is the application entry point.

**NOTE:** Some resources will be retained on stack deletion, as otherwise the deletion will fail because they need to be empty (S3 buckets, ECR repositories, etc.). You will need to  delete them manually; failing to do so might incur in costs. For your reference, the CloudFormation logical names for these resources are:

* `ArtifactStoreBucket`
* `ECRRepository`

### Architecture

The following architecture diagram illustrates what gets deployed:

![arch diagram](./arch_diagram.png)
