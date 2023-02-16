```
class DockerHub(object):
def __init__(self, url=None, version='v2', headers=None, jwt_token=None):
    self.version = version
    self.url = '{0}/{1}'.format(url or 'https://hub.docker.com', self.version)
    self.headers = headers or {}
    if jwt_token:
        self.headers['Authorization'] = 'JWT ' + jwt_token

def create_private_docker_hub_repo(self, reponame, orgname, jwt_token, summary=None, description=None):
    payload = {
        'description': summary or '',
        'full_description': description or '',
        'is_private': 'true',
        'name': reponame,
        'namespace': orgname
    }
    resp = requests.post(
        self.url + '/repositories/',
        data=payload,
        headers=self.headers,
    )
    return resp.json()

def set_group_permission_for_repo(self, repo, orgname, groupname, permission='read'):
    group_id = {it['name']: it['id'] for it in self.get_org_groups(orgname)}[groupname]
    if not permission in ('write', 'read'):
        raise Exception('permission must be write or read')
    resp = requests.post(
        'https://hub.docker.com/v2/repositories/{org}/{repo}/groups/'.format(
            org=orgname,
            repo=repo
        ),
        data={'group_id': group_id, 'permission': permission},
        headers=self.headers
    )
    return resp.json()

def get_org_groups(self, orgname):
    resp = requests.get(
        'https://hub.docker.com/v2/orgs/{org}/groups/?page_size=100'.format(org=orgname),
        headers=self.headers,
    )
    return resp.json()['results']
```
