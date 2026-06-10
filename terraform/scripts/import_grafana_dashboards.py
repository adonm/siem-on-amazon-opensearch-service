#!/usr/bin/env python3
import argparse
import json
import time
from pathlib import Path

import boto3
import requests


def url(endpoint):
    endpoint = endpoint.rstrip('/')
    if endpoint.startswith('https://'):
        return endpoint
    return f'https://{endpoint}'


def grafana_api(endpoint, token, method, path, payload=None):
    response = requests.request(
        method,
        f'{url(endpoint)}{path}',
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
        },
        json=payload,
        timeout=30)
    return response


def service_account_id(client, workspace_id):
    name = 'siem-terraform-importer'
    try:
        response = client.create_workspace_service_account(
            workspaceId=workspace_id, name=name, grafanaRole='ADMIN')
        return response['id']
    except client.exceptions.ConflictException:
        response = client.list_workspace_service_accounts(
            workspaceId=workspace_id, maxResults=100)
        for account in response.get('serviceAccounts', []):
            if account.get('name') == name:
                return account['id']
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--workspace-id', required=True)
    parser.add_argument('--workspace-endpoint', required=True)
    parser.add_argument('--opensearch-endpoint', required=True)
    parser.add_argument('--region', required=True)
    parser.add_argument('--dashboards-dir', type=Path, required=True)
    args = parser.parse_args()

    grafana = boto3.client('grafana', region_name=args.region)
    account_id = service_account_id(grafana, args.workspace_id)
    token_response = grafana.create_workspace_service_account_token(
        workspaceId=args.workspace_id,
        serviceAccountId=account_id,
        name=f'terraform-import-{int(time.time())}',
        secondsToLive=3600)
    token = token_response['serviceAccountToken']['key']

    datasource = {
        'access': 'proxy',
        'basicAuth': False,
        'isDefault': True,
        'jsonData': {
            'database': 'log-*',
            'flavor': 'opensearch',
            'sigV4Auth': True,
            'sigV4AuthType': 'workspace-iam-role',
            'sigV4Region': args.region,
            'timeField': '@timestamp',
            'version': '2.19.0',
        },
        'name': 'SIEM OpenSearch Serverless',
        'type': 'grafana-opensearch-datasource',
        'uid': 'siem-opensearch',
        'url': url(args.opensearch_endpoint),
    }
    response = grafana_api(args.workspace_endpoint, token, 'POST', '/api/datasources', datasource)
    if response.status_code == 409:
        response = grafana_api(args.workspace_endpoint, token, 'PUT', '/api/datasources/uid/siem-opensearch', datasource)
    response.raise_for_status()

    for path in sorted(args.dashboards_dir.glob('*.json')):
        if path.name == 'conversion_report.json':
            continue
        dashboard = json.loads(path.read_text())
        response = grafana_api(
            args.workspace_endpoint,
            token,
            'POST',
            '/api/dashboards/db',
            {'dashboard': dashboard, 'overwrite': True, 'folderId': 0})
        response.raise_for_status()
        print(f'imported {path.name}')


if __name__ == '__main__':
    main()
