# Securing Amazon SageMaker Studio internet traffic using AWS Network Firewall

by Yevgeniy Ilyin | on 22 APR 2021 | in Amazon SageMaker,


Amazon SageMaker Studio is a web-based fully integrated development environment (IDE) where you can perform end-to-end machine learning (ML) development to prepare data and build, train, and deploy models.

Like other AWS services, Studio supports a rich set of security-related features that allow you to build highly secure and compliant environments.

One of these fundamental security features allows you to launch Studio in your own Amazon Virtual Private Cloud (Amazon VPC). This allows you to control, monitor, and inspect network traffic within and outside your VPC using standard AWS networking and security capabilities. For more information, see Securing Amazon SageMaker Studio connectivity using a private VPC.

Customers in regulated industries, such as financial services, often don’t allow any internet access in ML environments. They often use only VPC endpoints for AWS services, and connect only to private source code repositories in which all libraries have been vetted both in terms of security and licensing. Customers may want to provide internet access but also have some controls such as domain name or URL filtering and allow access to only specific public repositories and websites, possibly packet inspection, or other network traffic-related security controls. For these cases, AWS Network Firewall and NAT gateway-based deployment may provide a suitable use case.

In this post, we show how you can use Network Firewall to build a secure and compliant environment by restricting and monitoring internet access, inspecting traffic, and using stateless and stateful firewall engine rules to control the network flow between Studio notebooks and the internet.

Depending on your security, compliance, and governance rules, you may not need to or cannot completely block internet access from Studio and your AI and ML workloads. You may have requirements beyond the scope of network security controls implemented by security groups and network access control lists (ACLs), such as application protocol protection, deep packet inspection, domain name filtering, and intrusion prevention system (IPS). Your network traffic controls may also require many more rules compared to what is currently supported in security groups and network ACLs. In these scenarios, you can use Network Firewall—a managed network firewall and IPS for your VPC.

## Solution overview
When you deploy Studio in your VPC, you control how Studio accesses the internet with the parameter AppNetworkAccessType (via the Amazon SageMaker API) or by selecting your preference on the console when you create a Studio domain.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213888960-cb7c1066-701f-44f8-97b1-824036b97064.png) |


If you select Public internet Only (`PublicInternetOnly`), all the ingress and egress internet traffic from Amazon SageMaker notebooks flows through an AWS managed internet gateway attached to a VPC in your SageMaker account. The following diagram shows this network configuration.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213888980-5591a362-5e2e-4868-b150-440bb2c2de48.png) |



Studio provides public internet egress through a platform-managed VPC for data scientists to download notebooks, packages, and datasets. Traffic to the attached [Amazon Elastic File System (Amazon EFS)](https://aws.amazon.com/efs/) volume always goes through the customer VPC and never through the public internet egress.

To use your own control flow for the internet traffic, like a NAT or internet gateway, you must set the AppNetworkAccessType parameter to VpcOnly (or select VPC Only on the console). When you launch your app, this creates an elastic network interface in the specified subnets in your VPC. You can apply all available layers of security control—[security groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html), network ACLs, VPC endpoints, AWS PrivateLink, or Network Firewall endpoints—to the internal network and internet traffic to exercise fine-grained control of network access in Studio. The following diagram shows the VpcOnly network configuration.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889013-1ed27ee6-0a71-41c1-ad7a-085e72c7cb2b.png) |


In this mode, the direct internet access to or from notebooks is completely disabled, and all traffic is routed through an elastic network interface in your private VPC. This also includes traffic from Studio UI widgets and interfaces, such as Experiments, Autopilot, and Model Monitor, to their respective backend SageMaker APIs.

For more information about network access parameters when creating a domain, see CreateDomain.

The solution in this post uses the VpcOnly option and deploys the Studio domain into a VPC with three subnets:

SageMaker subnet – Hosts all Studio workloads. All ingress and egress network flow is controlled by a security group.
NAT subnet – Contains a NAT gateway. We use the NAT gateway to access the internet without exposing any private IP addresses from our private network.
Network Firewall subnet – Contains a Network Firewall endpoint. The route tables are configured so that all inbound and outbound external network traffic is routed via Network Firewall. You can configure stateful and stateless Network Firewall policies to inspect, monitor, and control the traffic.
The following diagram shows the overview of the solution architecture and the deployed components.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889052-2348e2e6-9bcc-43e2-a98f-3be5eee990d0.png) |

### VPC resources
The solution deploys the following resources in your account:

A VPC with a specified Classless Inter-Domain Routing (CIDR) block
Three private subnets with specified CIDRs
Internet gateway, NAT gateway, Network Firewall, and a Network Firewall endpoint in the Network Firewall subnet
A Network Firewall policy and stateful domain list group with an allow domain list
Elastic IP allocated to the NAT gateway
Two security groups for SageMaker workloads and VPC endpoints, respectively
Four route tables with configured routes
An Amazon S3 VPC endpoint (type Gateway)
AWS service access VPC endpoints (type Interface) for various AWS services that need to be accessed from Studio
The solution also creates an AWS Identity and Access Management (IAM) execution role for SageMaker notebooks and Studio with preconfigured IAM policies.

Network routing for targets outside the VPC is configured in such a way that all ingress and egress internet traffic goes via the Network Firewall and NAT gateway. For details and reference network architectures with Network Firewall and NAT gateway, see Architecture with an internet gateway and a NAT gateway, Deployment models for AWS Network Firewall, and Enforce your AWS Network Firewall protections at scale with AWS Firewall Manager. The AWS re:Invent 2020 video Which inspection architecture is right for you? discusses which inspection architecture is right for your use case.

SageMaker resources
The solution creates a SageMaker domain and user profile.

The solution uses only one Availability Zone and is not highly available. A best practice is to use a Multi-AZ configuration for any production deployment. You can implement the highly available solution by duplicating the Single-AZ setup—subnets, NAT gateway, and Network Firewall endpoints—to additional Availability Zones.

You use Network Firewall and its policies to control entry and exit of the internet traffic in your VPC. You create an allow domain list rule to allow internet access to the specified network domains only and block traffic to any domain not on the allow list.

AWS CloudFormation resources
The source code and AWS CloudFormation template for solution deployment are provided in the GitHub repository. To deploy the solution on your account, you need:

An AWS account and the AWS Command Line Interface (AWS CLI) configured with administrator permissions
An Amazon Simple Storage Service (Amazon S3) bucket in your account in the same Region where you deploy the solution
Network Firewall is a Regional service; for more information on Region availability, see the AWS Region Table.

Your CloudFormation stack doesn’t have any required parameters. You may want to change the DomainName or *CIDR parameters to avoid naming conflicts with the existing resources and your VPC CIDR allocations. Otherwise, use the following default values:

ProjectName – sagemaker-studio-vpc-firewall
DomainName – sagemaker-anfw-domain
UserProfileName – anfw-user-profile
VPCCIDR – 10.2.0.0/16
FirewallSubnetCIDR – 10.2.1.0/24
NATGatewaySubnetCIDR – 10.2.2.0/24
SageMakerStudioSubnetCIDR – 10.2.3.0/24
Deploy the CloudFormation template
To start experimenting with the Network Firewall and stateful rules, you need first to deploy the provided CloudFormation template to your AWS account.

Clone the GitHub repository:
git clone https://github.com/aws-samples/amazon-sagemaker-studio-vpc-networkfirewall.git
cd amazon-sagemaker-studio-vpc-networkfirewall

Create an S3 bucket in the Region where you deploy the solution:
aws s3 mb s3://<your s3 bucket name>
You can skip this step if you already have an S3 bucket.

Deploy the CloudFormation stack:
make deploy CFN_ARTEFACT_S3_BUCKET=<your s3 bucket name>
The deployment procedure packages the CloudFormation template and copies it to the S3 bucket your provided. Then the CloudFormation template is deployed from the S3 bucket to your AWS account.

The stack deploys all the needed resources like VPC, network devices, route tables, security groups, S3 buckets, IAM policies and roles, and VPC endpoints, and also creates a new Studio domain and user profile.

When the deployment is complete, you can see the full list of stack output values by running the following command in terminal:

aws cloudformation describe-stacks \
    --stack-name sagemaker-studio-demo \
    --output table \
    --query "Stacks[0].Outputs[*].[OutputKey, OutputValue]"
Launch Studio via the SageMaker console.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889123-14c3ed4b-d573-45c2-bcc3-2157ad11c720.png) |

Experiment with Network Firewall
Now you can learn how to control the internet inbound and outbound access with Network Firewall. In this section, we discuss the initial setup, accessing resources not on the allow list, adding domains to the allow list, configuring logging, and additional firewall rules.

Initial setup
The solution deploys a Network Firewall policy with a stateful rule group with an allow domain list. This policy is attached to the Network Firewall. All inbound and outbound internet traffic is blocked now, except for the .kaggle.com domain, which is on the allow list.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889138-b292abbd-f19a-459b-a4ed-5f09bcacbf9c.png) |


Let’s try to access https://kaggle.com by opening a new notebook in Studio and attempting to download the front page from kaggle.com:

!wget https://kaggle.com
The following screenshot shows that the request succeeds because the domain is allowed by the firewall policy. Users can connect to this and only to this domain from any Studio notebook.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889155-ffbcde8b-5828-4d97-9782-b3704c99ad51.png) |


Access resources not on the allowed domain list
In the Studio notebook, try to clone any public GitHub repository, such as the following:

!git clone https://github.com/aws-samples/amazon-sagemaker-studio-vpc-networkfirewall.git
This operation times out after 5 minutes because any internet traffic except to and from the .kaggle.com domain isn’t allowed and is dropped by Network Firewall.

| |
| :--: | 
| ![image](https://user-images.githubusercontent.com/8270630/213889188-ceb42fab-cc70-4eeb-88c7-5cdc8baabd51.png) |


Add a domain to the allowed domain list
To be able to run the git clone command, you must allow internet traffic to the .github.com domain.

1. On the Amazon VPC console, choose Firewall policies.
2. Choose the policy network-firewall-policy-<ProjectName>.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889222-656924cb-9766-4abb-b2c8-e4c069edc338.png) |


3. In the Stateful rule groups section, select the group rule domain-allow-sagemaker-<ProjectName>.


You can see the domain .kaggle.com on the allow list.

4. Choose Add domain.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889247-21bd3059-2932-4923-9869-0c6b3cff0be6.png) |


5. Enter .github.com.
6. Choose Save.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889267-d399a869-6e54-48ef-8af7-73d457a1273a.png) |

You now have two names on the allow domain list.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889287-d3f6777a-30d2-4a92-996e-2cd4412cd77b.png) |


Firewall policy is propagated in real time to Network Firewall and your changes take effect immediately. Any inbound or outbound traffic from or to these domains is now allowed by the firewall and all other traffic is dropped.

To validate the new configuration, go to your Studio notebook and try to clone the same GitHub repository again:

!git clone https://github.com/aws-samples/amazon-sagemaker-studio-vpc-networkfirewall.git
The operation succeeds this time—Network Firewall allows access to the .github.com domain.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889311-418bd2cd-b8d8-4d79-be3b-0756bbc1ef4b.png) |


Network Firewall logging
In this section, you configure Network Firewall logging for your firewall’s stateful engine. Logging gives you detailed information about network traffic, including the time that the stateful engine received a packet, detailed information about the packet, and any stateful rule action taken against the packet. The logs are published to the log destination that you configured, where you can retrieve and view them.

On the Amazon VPC console, choose Firewalls.
Choose your firewall.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889344-3fdbdbee-6de3-4083-90cd-57f32de7159f.png) |


Choose the Firewall details tab.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889352-10da6802-f5d5-4a78-bdf9-ac21b0f13b25.png) |

In the Logging section, choose Edit.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889369-9ff00aa7-e1ce-4a97-9898-1c697ddbab07.png) |


Configure your firewall logging by selecting what log types you want to capture and providing the log destination.
For this post, select Alert log type, set Log destination for alerts to CloudWatch Log group, and provide an existing or a new log group where the firewall logs are delivered.

Choose Save.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889384-89116b40-1fdd-4eb6-821f-61a816c3ec6f.png) |


To check your settings, go back to Studio and try to access pypi.org to install a Python package:

!pip install -U scikit-learn
This command fails with ReadTimeoutError because Network Firewall drops any traffic to any domain not on the allow list (which contains only two domains: .github.com and .kaggle.com).

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889408-5304e8a7-0545-491f-9e4b-4f6cf94b9e72.png) |


On the Amazon CloudWatch console, navigate to the log group and browse through the recent log streams.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889420-911a39b9-8e2c-42a7-941b-88ad1dec632b.png) |


The pipy.org domain shows the blocked action. The log event also provides additional details such as various timestamps, protocol, port and IP details, event type, availability zone, and the firewall name.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889435-10c0f3fe-6fca-4796-81a3-5a71e7c06f51.png) |

You can continue experimenting with Network Firewall by adding .pypi.org and .pythonhosted.org domains to the allowed domain list.


| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889443-10060c69-8f32-4b1d-a7c7-b7a6869abd2d.png) |


Then validate your access to them via your Studio notebook.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889455-30f9a02c-cf44-4f1d-a979-b81f7afe6079.png) |


Additional firewall rules
You can create any other stateless or stateful firewall rules and implement traffic filtering based on a standard stateful 5-tuple rule for network traffic inspection (protocol, source IP, source port, destination IP, destination port). Network Firewall also supports industry standard stateful Suricata compatible IPS rule groups. You can implement protocol-based rules to detect and block any non-standard or promiscuous usage or activity. For more information about creating and managing Network Firewall rule groups, see Rule groups in AWS Network Firewall.

Additional security controls with Network Firewall
In the previous section, we looked at one feature of the Network Firewall: filtering network traffic based on the domain name. In addition to stateless or stateful firewall rules, Network Firewall provides several tools and features for further security controls and monitoring:

Central firewall management and visibility in AWS Firewall Manager. You can centrally manage security policies and automatically enforce mandatory security policies across existing and newly created accounts and VPCs.
Network Firewall logging for the firewall’s stateful engine. You can record flow and alert logs, and use the same or different logging destinations for each log type.
Stateless rules to filter network traffic based on protocol, source IP addresses, ranges, source port ranges, destination IP addresses and ranges, and TCP flags.
Integration into a broader set of AWS security components. For an example, see Automatically block suspicious traffic with AWS Network Firewall and Amazon GuardDuty.
Integration in a diverse ecosystem of Network Firewall Partners that complement Network Firewall, enabling the deployment of a comprehensive security architecture. For example use cases, see Full VPC traffic visibility with AWS Network Firewall and Sumo Logic and Splunk Named Launch Partner of AWS Network Firewall.
Build secure ML environments
A robust security design normally includes multi-layer security controls for the system. For SageMaker environments and workloads, you can use the following AWS security services and concepts to secure, control, and monitor your environment:

VPC and private subnets to perform secure API calls to other AWS services and restrict internet access for downloading packages.
S3 bucket policies that restrict access to specific VPC endpoints.
Encryption of ML model artifacts and other system artifacts that are either in transit or at rest. Requests to the SageMaker API and console are made over a Secure Sockets Layer (SSL) connection.
Restricted IAM roles and policies for SageMaker runs and notebook access based on resource tags and project ID.
Restricted access to Amazon public services, such as Amazon Elastic Container Registry (Amazon ECR) to VPC endpoints only.
For a reference deployment architecture and ready-to-use deployable constructs for your environment, see Amazon SageMaker with Guardrails on AWS.

Conclusion
In this post, we showed how you can secure, log, and monitor internet ingress and egress traffic in Studio notebooks for your sensitive ML workloads using managed Network Firewall. You can use the provided CloudFormation templates to automate SageMaker deployment as part of your Infrastructure as Code (IaC) strategy.

For more information about other possibilities to secure your SageMaker deployments and ML workloads, see Building secure machine learning environments with Amazon SageMaker.
