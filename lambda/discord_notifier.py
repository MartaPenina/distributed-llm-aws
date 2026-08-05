import json
import urllib.request
import os
DISCORD_WEBHOOK_URL = os.environ['DISCORD_WEBHOOK_URL']

def lambda_handler(event, context):
    for record in event['Records']:
        sns_message = record['Sns']['Message']
        subject = record['Sns'].get('Subject', 'AWS Alert')

        discord_payload = {
            "content": f"**{subject}**\n```{sns_message}```"
        }

        req = urllib.request.Request(
            DISCORD_WEBHOOK_URL,
            data=json.dumps(discord_payload).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (compatible; AWS-Lambda-Discord-Notifier)'
            }
        )
        urllib.request.urlopen(req)

    return {'statusCode': 200}