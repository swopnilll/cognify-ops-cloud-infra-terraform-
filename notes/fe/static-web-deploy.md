# Setup Static Website Using S3 Bucket

- S3
- Setup Cloud Formation with S3
- AWS Certificate Manager to Generate Certificate and configure certificate inside
  Route 53
- Configure Domain into Route 53 to Make DNS server work.
- With help of particular Domain, we should be able to access our website which is present in our S3 Bucket using the CloudFront Distribution.

![alt text](image.png)

1. User has a Domain www.jhooq.org
2. Once this Domain is entered in the browser by user, than the request will land into
   Route 53 will redirect that request to Cloud Front Distribution
3. Cloud Front Distribution is going to help the user to reduce the latency between the request to the resource.

4. Lets say if s3 is created in Europe region, but user can be present anyw
