```
aws cloudformation deploy \
	--stack-name microservices \
	--template-file template.yaml \
	--parameter-overrides \
		FontColorImageUri=carlosafonso/microservices-font-color \
		FontSizeImageUri=carlosafonso/microservices-font-size \
		WordImageUri=carlosafonso/microservices-word \
		FrontendImageUri=carlosafonso/microservices-frontend \
	--capabilities CAPABILITY_IAM
```
