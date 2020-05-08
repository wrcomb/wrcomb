#!/bin/bash

# Aleksandr Usov @ 2020
# example of the script to manage AWS cloud
# don't use it :)

AWS='aws'

dst='dst_bucket'
src='src_bucket'

id=$($AWS sts get-caller-identity | jq '.Account' | tr -d \")
policy_name="s3crr_for_${src}_to_${dst}"
policy_arn="arn:aws:iam::${id}:policy/service-role/${policy_name}"
role_name="s3crr_role_for_${src}"
role_name=$(echo $role_name|cut -b 1-64)
role_arn="arn:aws:iam::${id}:role/${role_name}"

# uncomment if don't want to create a new cmk
#key_arn="arn:aws:kms:eu-central-1:id:key/key_id"

function create_policy_document()
{
[[ -f /tmp/policy_document ]] && rm /tmp/policy_document
cat >/tmp/policy_document <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Action":[
            "s3:ListBucket",
            "s3:GetReplicationConfiguration",
            "s3:GetObjectVersionForReplication",
            "s3:GetObjectVersionAcl"
         ],
         "Effect":"Allow",
         "Resource":[
            "arn:aws:s3:::${src}",
            "arn:aws:s3:::${src}/*"
         ]
      },
      {
         "Action":[
            "s3:ReplicateObject",
            "s3:ReplicateDelete",
            "s3:ReplicateTags",
            "s3:GetObjectVersionTagging"
         ],
         "Effect":"Allow",
         "Resource":"arn:aws:s3:::${dst}/*"
      },
      {
         "Action":[
            "kms:Encrypt"
         ],
         "Effect":"Allow",
         "Condition":{
            "StringLike":{
               "kms:ViaService":"s3.eu-central-1.amazonaws.com",
               "kms:EncryptionContext:aws:s3:arn":[
                  "arn:aws:s3:::${dst}/*"
               ]
            }
         },
         "Resource":[
            "${key_arn}"
         ]
      }
   ]
}
EOF
}


function create_role_document()
{
[[ -f /tmp/role_document ]] && rm /tmp/role_document
cat >/tmp/role_document <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

function create_replication_document()
{
[[ -f /tmp/replication_document ]] && rm /tmp/replication_document
cat >/tmp/replication_document <<EOF
{
   "Role":"${role_arn}",
   "Rules":[
      {
         "Status":"Enabled",
         "Priority":1,
         "DeleteMarkerReplication":{
            "Status":"Disabled"
         },
         "Filter":{
            "Prefix":""
         },
         "Destination":{
            "Bucket":"arn:aws:s3:::${dst}",
            "EncryptionConfiguration":{
               "ReplicaKmsKeyID":"${key_arn}"
            }
         },
         "SourceSelectionCriteria":{
            "SseKmsEncryptedObjects":{
               "Status":"Disabled"
            }
         }
      }
   ]
}
EOF
}

function create_lifecycly_document()
{
[[ -f /tmp/lifecycle_document ]] && rm /tmp/lifecycle_document
cat >/tmp/lifecycle_document <<EOF
{
    "Rules": [
        {
            "Status": "Enabled",
            "Prefix": "",
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "GLACIER"
                }
            ],
            "NoncurrentVersionTransitions": [
                {
                    "NoncurrentDays": 30,
                    "StorageClass": "GLACIER"
                }
            ],
            "ID": "Move old objects to Glacier"
        }
    ]
}
EOF
}

output=$($AWS s3api list-buckets --query 'Buckets[].Name' | jq ".|map(contains(\"${src}\"))|any")
if [[ $output == false ]]
then
        echo "src bucket:${src} doesn't exist"
        exit 1
fi

output=$($AWS s3api get-bucket-versioning --bucket $src| jq '(.Status=="Enabled")')
if [[ $output != true ]]
then
        echo "Enabling versioning for $src"
        $AWS s3api put-bucket-versioning --bucket $src --versioning-configuration Status=Enabled
        [[ $? -ne 0 ]] && { echo "Can't enable versioning for $src"; exit 1; }
fi

output=$($AWS s3api list-buckets --query 'Buckets[].Name' | jq ".|map(contains(\"${dst}\"))|any")
if [[ $output == false ]]
then
        echo "Creating bucket: $dst"
        $AWS s3api create-bucket --acl private --bucket ${dst} --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1 &>/dev/null
        [[ $? -ne 0 ]] && { echo "Can't create the bucket:${dst}"; exit 1; }
fi

output=$($AWS s3api get-bucket-versioning --bucket $dst| jq '(.Status=="Enabled")')
if [[ $output != true ]]
then
        echo "Enabling versioning for $dst"
        $AWS s3api put-bucket-versioning --bucket $dst --versioning-configuration Status=Enabled
        [[ $? -ne 0 ]] && { echo "Can't enable versioning for $dst"; exit 1; }
fi

$AWS s3api get-bucket-encryption --bucket ${dst} &>/dev/null
if [[ $? -ne 0 ]]
then
        if [[ -z ${key_arn} ]]
        then
                cmk_id=$($AWS kms create-key --origin EXTERNAL --region eu-central-1|jq '.KeyMetadata.KeyId'|tr -d \")
        [[ $? -ne 0 ]] && { echo "Can't create key"; exit 1; }
                key_arn="arn:aws:kms:eu-central-1:${id}:key/${cmk_id}"
                $AWS kms get-parameters-for-import --key-id ${cmk_id} \
                        --wrapping-algorithm RSAES_OAEP_SHA_1 \
                        --wrapping-key-spec RSA_2048 --region eu-central-1 >/tmp/get-parameters-for-import
                [[ $? -ne 0 ]] && { echo "Can't download key"; exit 1; }
                cat /tmp/get-parameters-for-import | jq .PublicKey | cut -f 2 -d \" > PublicKey.b64
                openssl enc -d -base64 -A -in PublicKey.b64 -out PublicKey.bin
                openssl rand -out PlaintextKeyMaterial.bin 32
                openssl rsautl -encrypt \
                        -in PlaintextKeyMaterial.bin \
                        -oaep \
                        -inkey PublicKey.bin \
                        -keyform DER \
                        -pubin \
                        -out EncryptedKeyMaterial.bin
                cat /tmp/get-parameters-for-import | jq .ImportToken | cut -f 2 -d \" > ImportToken.b64
                openssl enc -d -base64 -A -in ImportToken.b64 -out ImportToken.bin
                $AWS kms import-key-material --key-id ${cmk_id} \
                        --encrypted-key-material fileb://EncryptedKeyMaterial.bin \
                        --import-token fileb://ImportToken.bin \
                        --expiration-model KEY_MATERIAL_DOES_NOT_EXPIRE --region eu-central-1
                [[ $? -ne 0 ]] && { echo "Can't import key"; exit 1; }
        fi
        $AWS s3api put-bucket-encryption \
                --bucket snap-drc-prod-bucket \
                --server-side-encryption-configuration "{
    \"Rules\": [
        {
            \"ApplyServerSideEncryptionByDefault\": {
                \"KMSMasterKeyID\": \"${key_arn}\",
                \"SSEAlgorithm\": \"aws:kms\"
            }
        }
    ]
}" --region eu-central-1
        [[ $? -ne 0 ]] && { echo "Can't apply encription"; exit 1; }
fi

$AWS s3api get-bucket-replication --bucket $src &>/dev/null

if [[ $? -ne 0 ]]
then
  $AWS iam get-policy --policy-arn ${policy_arn} &>/dev/null
  if [[ $? -ne 0 ]]
        then
                echo "Create a policy"
        create_policy_document
                $AWS iam create-policy --path /service-role/ --policy-name ${policy_name} --policy-document file:///tmp/policy_document &>/dev/null
                [[ $? -ne 0 ]] && { echo "Can't create policy ${policy_name}"; exit 1; }
  fi
        $AWS iam get-role --role-name ${role_name} &>/dev/null
        if [[ $? -ne 0 ]]
        then
                echo "Create a role"
                create_role_document
                $AWS iam create-role --role-name ${role_name} --assume-role-policy-document file:///tmp/role_document &>/dev/null
                [[ $? -ne 0 ]] && { echo "can't create role ${role_name}"; exit 1; }
        fi
        output=$($AWS iam list-attached-role-policies --role-name ${role_name} | jq '(.AttachedPolicies == [])')
        if [[ $output == true ]]
        then
                echo "Attaching the policy to the role"
                $AWS iam attach-role-policy --policy-arn ${policy_arn} --role-name ${role_name}
        fi
        echo "Syncing buckets"
        $AWS s3 sync "s3://${src}" "s3://${dst}"
        echo "Create replication for $src"
        create_replication_document
        $AWS s3api put-bucket-replication \
    --bucket $src \
    --replication-configuration file:///tmp/replication_document
        [[ $? -ne 0 ]] && { echo "can't create replication for ${src}"; exit 1; }
fi

$AWS s3api get-bucket-lifecycle-configuration --bucket $dst &>/dev/null

if [[ $? -ne 0 ]]
then
        echo "Configuring lifecycle configuration"
        create_lifecycly_document
        $AWS s3api put-bucket-lifecycle-configuration --bucket $dst --lifecycle-configuration  file:///tmp/lifecycle_document
        [[ $? -ne 0 ]] && { echo "can't create lifecycle for ${dst}"; exit 1; }
fi