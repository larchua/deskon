# Deskon API 快速参考

## 基础信息

- **Base URL**: `http://your-domain:21114/api`
- **认证**: Bearer Token (`Authorization: Bearer <token>`)
- **格式**: JSON

---

## 认证流程

```
登录 → 获取 token → 保存 token → 后续请求携带 token
```

---

## 核心 API 端点

### 认证

| 方法 | 端点 | 描述 | 认证 |
|------|------|------|------|
| `POST` | `/api/register` | 用户注册 | ❌ |
| `POST` | `/api/login` | 用户登录 | ❌ |
| `POST` | `/api/logout` | 用户登出 | ❌ |
| `POST` | `/api/currentUser` | 获取当前用户 | ✅ |

### 地址簿

| 方法 | 端点 | 描述 | 认证 |
|------|------|------|------|
| `GET` | `/api/ab` | 获取地址簿 | ✅ |
| `POST` | `/api/ab` | 更新地址簿 | ✅ |
| `POST` | `/api/ab/get` | 获取地址簿（兼容） | ✅ |

### 设备管理

| 方法 | 端点 | 描述 | 认证 |
|------|------|------|------|
| `POST` | `/api/sysinfo` | 注册/更新设备 | ❌ |
| `POST` | `/api/heartbeat` | 心跳保活 | ❌ |
| `POST` | `/api/audit` | 审计日志 | ❌ |

---

## 快速开始示例

### JavaScript/TypeScript

```typescript
const API_BASE = 'http://your-domain:21114/api';

// 1. 注册用户（可选）
const register = async (username: string, password: string) => {
  const response = await fetch(`${API_BASE}/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password })
  });
  const data = await response.json();
  if (data.code === 1) {
    return data.user;
  }
  throw new Error(data.error || 'Registration failed');
};

// 2. 登录
const login = async (username: string, password: string, id: string, uuid: string) => {
  const response = await fetch(`${API_BASE}/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password, id, uuid })
  });
  const data = await response.json();
  if (data.access_token) {
    localStorage.setItem('access_token', data.access_token);
    return data.access_token;
  }
  throw new Error(data.error || 'Login failed');
};

// 3. 获取地址簿
const getAddressBook = async () => {
  const token = localStorage.getItem('access_token');
  const response = await fetch(`${API_BASE}/ab`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const result = await response.json();
  return JSON.parse(result.data);
};

// 4. 心跳保活
const heartbeat = async (id: string, uuid: string) => {
  await fetch(`${API_BASE}/heartbeat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id, uuid })
  });
};
```

### Python

```python
import requests

API_BASE = 'http://your-domain:21114/api'

# 1. 注册用户（可选）
def register(username, password):
    response = requests.post(f'{API_BASE}/register', json={
        'username': username,
        'password': password
    })
    data = response.json()
    if data.get('code') == 1:
        return data['user']
    raise Exception(data.get('error', 'Registration failed'))

# 2. 登录
def login(username, password, client_id, uuid):
    response = requests.post(f'{API_BASE}/login', json={
        'username': username,
        'password': password,
        'id': client_id,
        'uuid': uuid
    })
    data = response.json()
    if 'access_token' in data:
        return data['access_token']
    raise Exception(data.get('error', 'Login failed'))

# 3. 获取地址簿
def get_address_book(access_token):
    headers = {'Authorization': f'Bearer {access_token}'}
    response = requests.get(f'{API_BASE}/ab', headers=headers)
    result = response.json()
    import json
    return json.loads(result['data'])

# 4. 心跳
def heartbeat(client_id, uuid):
    requests.post(f'{API_BASE}/heartbeat', json={
        'id': client_id,
        'uuid': uuid
    })
```

### cURL

```bash
# 登录
TOKEN=$(curl -s -X POST http://localhost:21114/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"pass","id":"123","uuid":"456"}' \
  | jq -r '.access_token')

# 获取地址簿
curl -X GET http://localhost:21114/api/ab \
  -H "Authorization: Bearer $TOKEN"

# 心跳
curl -X POST http://localhost:21114/api/heartbeat \
  -H "Content-Type: application/json" \
  -d '{"id":"123","uuid":"456"}'
```

---

## 请求/响应格式

### 注册请求

```json
POST /api/register
{
  "username": "string",
  "password": "string"
}
```

### 注册响应（成功）

```json
{
  "code": 1,
  "message": "注册成功！",
  "user": {
    "username": "string",
    "is_admin": false
  }
}
```

### 登录请求

```json
POST /api/login
{
  "username": "string",
  "password": "string",
  "id": "string",
  "uuid": "string"
}
```

### 登录响应

```json
{
  "access_token": "string",
  "type": "access_token",
  "user": { "name": "string" }
}
```

### 地址簿响应

```json
{
  "updated_at": "datetime",
  "data": "{\"tags\":[],\"peers\":[],\"tag_colors\":{}}"
}
```

---

## 错误处理

所有错误响应格式：

```json
{
  "error": "错误信息"
}
```

常见错误：
- `请求方式错误！` - 使用错误的HTTP方法
- `帐号或密码错误！` - 登录失败
- `拉取列表错误！` - Token无效或过期

---

## Token 管理

- **有效期**: 7200秒 (2小时)
- **延长**: 通过 `/api/heartbeat` 延长
- **存储**: 建议使用安全存储（localStorage/加密存储）

---

## 数据模型

### Peer
```typescript
{
  id: string,
  username: string,
  hostname: string,
  alias: string,
  platform: string,
  tags: string[],
  hash: string
}
```

### AddressBook
```typescript
{
  tags: string[],
  peers: Peer[],
  tag_colors: { [key: string]: number }
}
```

---

## 完整文档

详细文档请参考 [API_DOCUMENTATION.md](./API_DOCUMENTATION.md)

