const express = require('express');
const AWS = require('aws-sdk');
const app = express();

AWS.config.update({
    region: 'ap-northeast-2',
});

const ec2 = new AWS.EC2();

app.get('/allowlist', async (req, res) => {
    const ipAddress = req.query.ip;
    const securityGroupId = 'SG_GROUP_ID';

    try {
        await ec2.authorizeSecurityGroupIngress({
            GroupId: securityGroupId,
            IpPermissions: [{
                IpProtocol: 'tcp',
                FromPort: 2222,
                ToPort: 2222,
                IpRanges: [{
                    CidrIp: `${ipAddress}/32`,
                }],
            }],
        }).promise();

        setTimeout(async () => {
            await ec2.revokeSecurityGroupIngress({
                GroupId: securityGroupId,
                IpPermissions: [{
                    IpProtocol: 'tcp',
                    FromPort: 2222,
                    ToPort: 2222,
                    IpRanges: [{
                        CidrIp: `${ipAddress}/32`,
                    }],
                }],
            }).promise();
        }, 900000); // 15 minutes in milliseconds

        console.log(`Adding IP address ${ipAddress} to allowlist.`);

        res.send(`IP address ${ipAddress} added to allowlist.`);
    } catch (error) {
        console.error('Error:', error);
        res.status(500).send('Error adding IP address to allowlist.');
    }
});

app.get('/healthz', (req, res) => {
    res.status(200).send('healthy');
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});