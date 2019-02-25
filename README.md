# CPQ-Calculate

Used to calculate and save up to 7,000 Salesforce CPQ quotes from APEX

## Quick Start
[![Deploy](https://deploy-to-sfdx.com/dist/assets/images/DeployToSFDX.svg)](https://deploy-to-sfdx.com)

### sandbox or production deploy
1. Clone this repo
2. Install the [SFDX CLI](https://developer.salesforce.com/tools/sfdxcli) 
3. Connect to your org: `sfdx force:auth:web:login`
4. Enter your org's credential, login, then dismiss the browser
5. Set your org as the default org: `sfdx force:config:set defaultdevhubusername=[your dev org's user name]`
6. Verify that your org is now default: `sfdx force:org:list`
7. Your org should show up with a (D) in front of it

Deploy the code from this repo
 
1. Convert source to mdapi package format: `sfdx force:source:convert -d src`
2. Deploy source to org: `sfdx force:mdapi:deploy -d src`
3. Monitor the deployment status: `sfdx force:mdapi:deploy:report`

You're done once status is succeeded

### anonymous APEX

```
Id[] quoteIds; // initialize this list up to 7,000 SBQQ__Quote__c ids
CPQBatchCalculator.start(quoteIds);
```