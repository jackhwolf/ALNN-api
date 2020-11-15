import boto3
from botocore.exceptions import ClientError
from pathlib import Path
from uuid import uuid4
import json
from collections import OrderedDict
import pandas as pd
import time
import numpy as np

'''
App contains the main logic for getting/filtering the results data
'''
class App:

    def __init__(self):
        self.main_key = 'main.json'
        self.buckets = {
            'main': 'alnn-main-bucket-8nyb87yn8',
            'animations': 'alnn-animations-bucket-8nyb87yn8',
            'zipfiles': 'alnn-zipfiles-bucket-8nyb87yn8'
        }

    def get_body(self):
        main = self.download_main_as_df()
        out = None
        if main is None:
            empty = []
            empty.append({'r1': 'v1', 'Animation': 'https://www.youtube.com/watch?v=ONqETis6nX0'})
            empty.append({'r1': 'v2', 'Animation': 'https://www.youtube.com/watch?v=ONqETis6nX0'})
            out = empty
        else:
            body = [self.format_row(row) for _, row in main.iterrows()]
            out = body
        return json.dumps(out)

    def format_row(self, row):
        out = OrderedDict({})
        row = row.to_dict()
        out['Name'] = row['input']['experiment_name']
        out['Hidden_Nodes'] = row['input']['model_args']['hidden_nodes']
        out['LR'] = row['input']['model_args']['lr']
        out['WD'] = row['input']['model_args']['wd']
        out['Loss'] = row['input']['model_args']['loss_function']
        out['Optim'] = row['input']['model_args']['optimizer_function']
        out['Max_Loss'] = np.round(row['analytics']['max_loss'], 3)
        out['Avg_Loss'] = np.round(row['analytics']['avg_loss'], 3)
        out['Data'] = row['input']['data']
        out['Data_Args'] = '\n'.join([f"{k}: {v}" for k, v in row['input']['data_args'].items()])
        out['Animation'] = self.get_obj_url(self.buckets['animations'], row['cloud_graphs']['animation_key'])
        return out

    def s3client(self):
        client = boto3.client("s3")
        return client

    def download_main_as_df(self):
        s3 = self.s3client()
        try:
            tmpfile = Path(f'/tmp/alnn_main_download_{int(time.time())}')
            tmpfile.touch()
            tmpfilepath = str(tmpfile.resolve())
            with open(tmpfilepath, 'wb') as f:
                s3.download_fileobj(self.buckets['main'], self.main_key, f)
            main = pd.read_json(tmpfilepath)
            del main['output']
            out = main
            tmpfile.unlink()
            return out
        except ClientError:
            return None

    def get_obj_url(self, bucket, key):
        url_template = "https://{}.s3.us-east-2.amazonaws.com/{}"
        return url_template.format(bucket, key)

def lambda_handler(event, context):
    app = App()
    body = app.get_body()
    out = {
        'statusCode': 200, 
        'headers': {
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET',
            'content-type': 'application/json',
        },
        'body': body
    }
    return out

# if __name__ =='__main__':
#     print(App().download_main_as_df())