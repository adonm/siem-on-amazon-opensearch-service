#!/usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
__copyright__ = ('Copyright Amazon.com, Inc. or its affiliates. '
                 'All Rights Reserved.')
__version__ = '2.10.4'
__license__ = 'MIT-0'
__author__ = 'Akihiro Nakajima'
__url__ = 'https://github.com/aws-samples/siem-on-amazon-opensearch-service'

import json
import logging
import re

logger = logging.getLogger(__name__)


class MyAoss:

    def __init__(self, client, collection_name, generation='CLASSIC'):
        self.client = client
        self.col_name = collection_name
        self.generation = generation

    @property
    def is_nextgen(self):
        return self.generation == 'NEXTGEN'

    @property
    def collection_group_name(self):
        # OpenSearch Serverless collection group names must start with a
        # lowercase letter and contain only lowercase letters, numbers, and
        # hyphens. Keep this deterministic so stack updates target the same
        # group for a given collection name.
        normalized = re.sub(r'[^a-z0-9-]+', '-', self.col_name.lower())
        normalized = normalized.strip('-')
        if not normalized or not normalized[0].isalpha():
            normalized = f'a-{normalized}'
        return f'nextgen-{normalized}'[:32].rstrip('-')

    def check_collection_creating_necessity(self):
        response = self.client.batch_get_collection(
            names=[self.col_name])
        if len(response['collectionDetails']) == 0:
            logger.info('Collection not found')
            create_new_domain = True
        elif len(response['collectionDetails']) == 1:
            logger.info('Collection already exists')
            create_new_domain = False
        return create_new_domain

    def _check_collection_group_creating_necessity(self):
        response = self.client.batch_get_collection_group(
            names=[self.collection_group_name])
        if len(response['collectionGroupDetails']) == 0:
            logger.info('Collection group not found')
            return True
        logger.info('Collection group already exists')
        return False

    def _create_collection_group(self):
        if not self.is_nextgen:
            return
        if not self._check_collection_group_creating_necessity():
            return
        response = self.client.create_collection_group(
            description='Created By SIEM Solution',
            generation='NEXTGEN',
            name=self.collection_group_name,
            standbyReplicas='DISABLED',
        )
        logger.debug(response)

    def _configure_aoss_encryption_policy(self):
        logger.info('Configure encryption policy for OpenSearch Serverless')
        aoss_encryption_policy = {
            "Rules": [
                {"ResourceType": "collection",
                 "Resource": [f"collection/{self.col_name}"]}],
            "AWSOwnedKey": True
        }
        try:
            response = self.client.create_security_policy(
                description="Created By SIEM Solution. DO NOT EDIT",
                name=f'siem-auto-{self.col_name}',
                policy=json.dumps(
                    aoss_encryption_policy, separators=(',', ':')),
                type="encryption"
            )
            logger.debug(response)
            is_successful = True
        except self.client.exceptions.ConflictException:
            is_successful = True
        except Exception as e:
            logger.error(e)
            is_successful = False
        return is_successful

    def _configure_aoss_network_policy(self, vpce_id):
        logger.info('Configure netowrk policy for OpenSearch Serverless')
        aoss_network_policy = [
            {
                "Rules": [
                    {"ResourceType": "collection",
                     "Resource": [f"collection/{self.col_name}"]},
                    {"ResourceType": "dashboard",
                     "Resource": [f"collection/{self.col_name}"]}
                ],
                "AllowFromPublic": True,
            }
        ]
        if vpce_id:
            aoss_network_policy[0]['AllowFromPublic'] = False
            aoss_network_policy[0]['SourceVPCEs'] = [vpce_id]
        logger.debug(json.dumps(aoss_network_policy))
        aoss_network_policy_json = json.dumps(
            aoss_network_policy, separators=(',', ':'))
        name = f'siem-auto-{self.col_name}'
        description = "Created By SIEM Solution. DO NOT EDIT"

        # check whether security policy exists
        try:
            res = self.client.get_security_policy(name=name, type='network')
            policy_version = res['securityPolicyDetail']['policyVersion']
        except self.client.exceptions.ResourceNotFoundException as err:
            policy_version = None
            logger.info(str(err))
        except Exception as err:
            policy_version = None
            logger.error(err)

        try:
            if policy_version:
                logger.info('update existing policy')
                response = self.client.update_security_policy(
                    type="network", name=name, description=description,
                    policy=aoss_network_policy_json,
                    policyVersion=policy_version,
                )
            elif not policy_version:
                logger.info('create new policy')
                response = self.client.create_security_policy(
                    type="network", name=name, description=description,
                    policy=aoss_network_policy_json,
                )
            logger.debug(response)
            is_successful = True
        except self.client.exceptions.ConflictException:
            is_successful = True
        except Exception as e:
            logger.error(e)
            is_successful = False
        return is_successful

    def create_collection(self, vpce_id):
        if self.is_nextgen:
            self._create_collection_group()
        is_successful = self._configure_aoss_encryption_policy()
        if is_successful:
            is_successful = self._configure_aoss_network_policy(vpce_id)
        if is_successful:
            collection_config = {
                'description': 'Created By SIEM Solution',
                'name': self.col_name,
                'type': 'SEARCH' if self.is_nextgen else 'TIMESERIES'
            }
            if self.is_nextgen:
                collection_config.update({
                    'collectionGroupName': self.collection_group_name,
                    'encryptionConfig': {'aWSOwnedKey': True},
                    'standbyReplicas': 'DISABLED',
                })
            response = self.client.create_collection(**collection_config)
            logger.debug(response)

    def update_collection(self, vpce_id):
        is_successful = self._configure_aoss_network_policy(vpce_id)
        print(is_successful)

    def get_collection_status(self):
        """
        response = self.client.list_collections(
            collectionFilters={'name': self.col_name},
            maxResults=1
        )
        if len(response['collectionSummaries']) == 1:
            return response['collectionSummaries'][0]['status']
        else:
            return None
        """
        response = self.client.batch_get_collection(
            names=[self.col_name]
        )
        logger.debug(response)
        if len(response['collectionDetails']) == 1:
            return response['collectionDetails'][0]['status']
        else:
            return None

    def get_endpoint_and_type(self):
        logger.info('get_aoss_endpoint_and_type')
        response = self.client.batch_get_collection(
            names=[self.col_name]
        )
        logger.debug(response)
        for collection in response['collectionDetails']:
            if collection['name'] == self.col_name:
                endpoint = collection['collectionEndpoint'].split('/')[2]
                aoss_type = collection['type']
                break
        return endpoint, aoss_type
