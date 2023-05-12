# Build secure ML environments

Use AWS network firewall to provide fine grained control over network traffic. 

## What does this fix?

Pytorch, a third party python library was [compromised on the Python Package Index code repository and runs a malicous binary.](https://thehackernews.com/2023/01/pytorch-machine-learning-framework.html) This impacts a recent nightly build. This build has been fixed and the problem resolved.

The attack uploads all of this information, including file contents (.ssh, .gitconfig), via encrypted DNS queries to the domain *.h4ck[.]cfd, using the DNS server wheezy[.]io

The package is using encrypted DNS and you can't monitor DNS traffic without TLS inspection like the Bayer proxies do.

## Who should use this solution? 

The infrastructure is complicated to setup. Advanced knowledge of VPCs and Sagemaker is assumed. 

Sagemaker users, however can easily modify the setup to mange their network; allow traffic by adding a domain name, e.g. **kaggle.com** to the environment. 

## Launch Studio via the SageMaker console.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889123-14c3ed4b-d573-45c2-bcc3-2157ad11c720.png) |

## Experiment with Network Firewall

Here we show how to control the internet inbound and outbound access with Network Firewall. In this section, we discuss the initial setup, accessing resources not on the allow list, adding domains to the allow list, configuring logging, and additional firewall rules.

### Initial setup
The solution deploys a Network Firewall policy with a stateful rule group with an allow domain list. This policy is attached to the Network Firewall. All inbound and outbound internet traffic is blocked now, except for the **.kaggle.com** domain, which is on the allow list.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889138-b292abbd-f19a-459b-a4ed-5f09bcacbf9c.png) |


We try to access `https://kaggle.com` by opening a new notebook in Studio and attempting to download the front page from `kaggle.com` using `wget` from a shell.

The following screenshot shows that the request succeeds because the domain is allowed by the firewall policy. Users can connect to this and only to this domain from any Studio notebook.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889155-ffbcde8b-5828-4d97-9782-b3704c99ad51.png) |


#### Access resources not on the allowed domain list
In the Studio notebook, try to clone any public GitHub repository, such as the following:

`!git clone https://github.com/aws-samples/amazon-sagemaker-studio-vpc-networkfirewall.git`
This operation times out after 5 minutes because any internet traffic except to and from the .kaggle.com domain isn’t allowed and is dropped by Network Firewall.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889188-ceb42fab-cc70-4eeb-88c7-5cdc8baabd51.png) |


#### Add a domain to the allowed domain list
To be able to run the git clone command, you must allow internet traffic to the **.github.com** domain.

1. On the Amazon VPC console, choose Firewall policies.
2. Choose the policy network-firewall-policy-<ProjectName>.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889222-656924cb-9766-4abb-b2c8-e4c069edc338.png) |


3. In the Stateful rule groups section, select the group rule domain-allow-sagemaker-<ProjectName>.


You can see the domain `.kaggle.com` on the allow list.

4. Choose Add domain.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889247-21bd3059-2932-4923-9869-0c6b3cff0be6.png) |


5. Enter `.github.com`.
6. Choose Save.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889267-d399a869-6e54-48ef-8af7-73d457a1273a.png) |

You now have two names on the allow domain list.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889287-d3f6777a-30d2-4a92-996e-2cd4412cd77b.png) |


Firewall policy is propagated in real time to Network Firewall and your changes take effect immediately. Any inbound or outbound traffic from or to these domains is now allowed by the firewall and all other traffic is dropped.

To validate the new configuration, go to Sagemaker Studio notebook and try to clone the same GitHub repository again:

`!git clone https://github.com/aws-samples/amazon-sagemaker-studio-vpc-networkfirewall.git`
The operation succeeds this time—Network Firewall allows access to the **.github.com** domain.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889311-418bd2cd-b8d8-4d79-be3b-0756bbc1ef4b.png) |


### Network Firewall logging
In this section, you configure Network Firewall logging for your firewall’s stateful engine. Logging gives you detailed information about network traffic, including the time that the stateful engine received a packet, detailed information about the packet, and any stateful rule action taken against the packet. The logs are published to the log destination that you configured, where you can retrieve and view them.

1. On the Amazon VPC console, choose **Firewalls**.
2. Choose your firewall.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889344-3fdbdbee-6de3-4083-90cd-57f32de7159f.png) |


3. Choose the **Firewall details** tab.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889352-10da6802-f5d5-4a78-bdf9-ac21b0f13b25.png) |

In the **Logging** section, choose **Edit**.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889369-9ff00aa7-e1ce-4a97-9898-1c697ddbab07.png) |


5. Configure your firewall logging by selecting what log types you want to capture and providing the log destination.

For this post, select Alert log type, set Log destination for alerts to CloudWatch Log group, and provide an existing or a new log group where the firewall logs are delivered.

6. Choose **Save**.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889384-89116b40-1fdd-4eb6-821f-61a816c3ec6f.png) |


To check your settings, go back to Studio and try to access `pypi.org` to install a Python package:

`!pip install -U scikit-learn`
This command fails with `ReadTimeoutError` because Network Firewall drops any traffic to any domain not on the allow list (which contains only two domains: `.github.com` and `.kaggle.com`).

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889408-5304e8a7-0545-491f-9e4b-4f6cf94b9e72.png) |


On the [Amazon CloudWatch console](http://aws.amazon.com/cloudwatch), navigate to the log group and browse through the recent log streams.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889420-911a39b9-8e2c-42a7-941b-88ad1dec632b.png) |


The `pipy.org` domain shows the `blocked` action. The log event also provides additional details such as various timestamps, protocol, port and IP details, event type, availability zone, and the firewall name.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889435-10c0f3fe-6fca-4796-81a3-5a71e7c06f51.png) |

You can continue experimenting with Network Firewall by adding `.pypi.org` and `.pythonhosted.org` domains to the allowed domain list.


| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889443-10060c69-8f32-4b1d-a7c7-b7a6869abd2d.png) |


Then validate your access to them via your Studio notebook.

| |
| :--: |
| ![image](https://user-images.githubusercontent.com/8270630/213889455-30f9a02c-cf44-4f1d-a979-b81f7afe6079.png) |


#### Additional firewall rules
You can create any other stateless or stateful firewall rules and implement traffic filtering based on a standard stateful 5-tuple rule for network traffic inspection (protocol, source IP, source port, destination IP, destination port). Network Firewall also supports industry standard stateful [Suricata compatible IPS rule groups.](https://docs.aws.amazon.com/network-firewall/latest/developerguide/stateful-rule-groups-ips.html) You can implement protocol-based rules to detect and block any non-standard or promiscuous usage or activity. For more information about creating and managing Network Firewall rule groups, see [Rule groups in AWS Network Firewall.](https://docs.aws.amazon.com/network-firewall/latest/developerguide/rule-groups.html)

### Additional security controls with Network Firewall
In the previous section, we looked at one feature of the Network Firewall: filtering network traffic based on the domain name. In addition to stateless or stateful firewall rules, Network Firewall provides several tools and features for further security controls and monitoring:

- Central firewall management and visibility in [AWS Firewall Manager](https://aws.amazon.com/firewall-manager/). You can centrally manage security policies and automatically enforce mandatory security policies across existing and newly created accounts and VPCs.

- [Network Firewall logging](https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewall-logging.html) for the firewall’s stateful engine. You can record flow and alert logs, and use the same or different logging destinations for each log type.

- [Stateless rules](https://docs.aws.amazon.com/network-firewall/latest/developerguide/stateless-rule-groups-5-tuple.html) to filter network traffic based on protocol, source IP addresses, ranges, source port ranges, destination IP addresses and ranges, and TCP flags.

- Integration into a broader set of AWS security components. For an example, see [Automatically block suspicious traffic with AWS Network Firewall and Amazon GuardDuty.](https://aws.amazon.com/blogs/security/automatically-block-suspicious-traffic-with-aws-network-firewall-and-amazon-guardduty/)

- Integration in a diverse ecosystem of Network Firewall Partners that complement Network Firewall, enabling the deployment of a comprehensive security architecture. For example use cases, see [Full VPC traffic visibility with AWS Network Firewall and Sumo Logic](https://www.sumologic.com/blog/aws-network-firewall-security/) and [Splunk Named Launch Partner of AWS Network Firewall.](https://www.splunk.com/en_us/blog/partners/splunk-named-launch-partner-of-aws-network-firewall.html)

### Build secure ML environments
A robust security design normally includes multi-layer security controls for the system. For SageMaker environments and workloads, you can use the following AWS security services and concepts to secure, control, and monitor your environment:

- VPC and private subnets to perform secure API calls to other AWS services and restrict internet access for downloading packages.
- S3 bucket policies that restrict access to specific VPC endpoints.
- Encryption of ML model artifacts and other system artifacts that are either in transit or at rest. Requests to the SageMaker API and console are made over a Secure Sockets Layer (SSL) connection.
- Restricted IAM roles and policies for SageMaker runs and notebook access based on resource tags and project ID.
- Restricted access to Amazon public services, such as [Amazon Elastic Container Registry (Amazon ECR)](http://aws.amazon.com/ecr/) to VPC endpoints only.
- For a reference deployment architecture and ready-to-use deployable constructs for your environment, see Amazon SageMaker with Guardrails on AWS.

## Conclusion
In this post, we showed how you can secure, log, and monitor internet ingress and egress traffic in Studio notebooks for your sensitive ML workloads using managed Network Firewall. You can use the provided CloudFormation templates to automate SageMaker deployment as part of your Infrastructure as Code (IaC) strategy.

For more information about other possibilities to secure your SageMaker deployments and ML workloads, see [Building secure machine learning environments with Amazon SageMaker.](https://aws.amazon.com/blogs/machine-learning/building-secure-machine-learning-environments-with-amazon-sagemaker/)
