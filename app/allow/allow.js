const fastify = require('fastify')({ logger: true })
const { EC2Client, AuthorizeSecurityGroupIngressCommand, RevokeSecurityGroupIngressCommand } = require('@aws-sdk/client-ec2')

const groupId = process.env.GROUP_ID
const port = 2222

const ec2 = new EC2Client({ region: 'ap-northeast-2' })

async function allowIp (ip) {
  const createCommand = new AuthorizeSecurityGroupIngressCommand({
    GroupId: groupId,
    IpPermissions: [{
      FromPort: port,
      ToPort: port,
      IpProtocol: 'tcp',
      IpRanges: [{
        CidrIp: `${ip}/32`
      }]
    }]
  })

  await ec2.send(createCommand)
}

async function blockIp (ip) {
  const createCommand = new RevokeSecurityGroupIngressCommand({
    GroupId: groupId,
    IpPermissions: [{
      FromPort: port,
      ToPort: port,
      IpProtocol: 'tcp',
      IpRanges: [{
        CidrIp: `${ip}/32`
      }]
    }]
  })

  await ec2.send(createCommand)
}

fastify.get('/allowlist', async (req, res) => {
  await allowIp(req.query.ip)
  res.send({ success: true })

  setTimeout(() => {
    blockIp(req.query.ip)
  }, 15 * 60 * 1000)
})

fastify.get('/healthz', (req, res) => {
  res.send({ success: true })
})

fastify.listen({ port: 8080, host: '0.0.0.0' }, (err) => {
  if (err) {
    fastify.log.error(err)
    process.exit(1)
  }
})