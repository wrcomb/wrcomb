import boto3

s3 = boto3.client('s3')
dynamodb = boto3.client('dynamodb')

table_name = 'dynamodb_table_name'

def handler(event, context):
    :
