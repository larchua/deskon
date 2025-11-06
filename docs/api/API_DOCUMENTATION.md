# Deskon API 文档

## 概述

Deskon API 提供了一套完整的远程桌面管理接口，支持客户端进行用户认证、设备管理、地址簿同步等功能。

**Base URL**: `http://your-domain:21114/api`

**认证方式**: Bearer Token (通过 HTTP Header `Authorization: Bearer <access_token>`)

---

## 认证流程

### 1. 用户注册（可选）

如果系统允许注册，客户端可以先注册用户账号。

### 2. 用户登录获取 Token

客户端需要通过登录接口获取 `access_token`，后续所有需要认证的请求都需要在 Header 中携带该 token。

```http
POST /api/login
```

---

## API 端点

### 认证相关

#### 1. 用户注册

**端点**: `POST /api/register`

**描述**: 注册新用户账号。客户端可以直接调用此接口进行用户注册。

**注意**: 
- 注册功能受 `ALLOW_REGISTRATION` 配置控制，如果系统未开放注册，将返回错误
- 第一个注册的用户自动获得管理员权限
- 注册成功后可直接使用登录接口登录

**请求体** (JSON):

```json
{
  "username": "string",    // 用户名（必填，3位以上）
  "password": "string"     // 密码（必填，8-20位）
}
```

**响应** (成功):

```json
{
  "code": 1,
  "message": "注册成功！",
  "user": {
    "username": "newuser",
    "is_admin": false
  }
}
```

**响应** (失败 - 注册未开放):

```json
{
  "error": "当前未开放注册，请联系管理员！"
}
```

**响应** (失败 - 用户名已存在):

```json
{
  "error": "用户名已存在。"
}
```

**响应** (失败 - 用户名太短):

```json
{
  "error": "用户名不得小于3位。"
}
```

**响应** (失败 - 密码长度不符合):

```json
{
  "error": "密码长度不符合要求, 应在8~20位。"
}
```

**验证规则**:
- 用户名：至少3个字符，不能为空
- 密码：8-20个字符，不能为空
- 用户名不能重复

**示例代码** (JavaScript):

```javascript
const response = await fetch('http://your-domain:21114/api/register', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    username: 'newuser',
    password: 'mypassword123'
  })
});

const data = await response.json();
if (data.code === 1) {
  console.log('注册成功！', data.user);
  // 注册成功后可以立即登录
  // await login(data.user.username, 'mypassword123');
} else {
  console.error('注册失败:', data.error);
}
```

**示例代码** (Python):

```python
import requests

url = "http://your-domain:21114/api/register"
payload = {
    "username": "newuser",
    "password": "mypassword123"
}

response = requests.post(url, json=payload)
data = response.json()

if data.get('code') == 1:
    print(f"注册成功！用户名: {data['user']['username']}")
    print(f"是否为管理员: {data['user']['is_admin']}")
else:
    print(f"注册失败: {data.get('error')}")
```

**示例代码** (cURL):

```bash
curl -X POST http://localhost:21114/api/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser",
    "password": "mypassword123"
  }'
```

**完整注册+登录流程**:

```javascript
// 1. 注册用户
async function registerAndLogin(username, password) {
  // 注册
  const registerResponse = await fetch('http://your-domain:21114/api/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password })
  });
  
  const registerData = await registerResponse.json();
  
  if (registerData.code !== 1) {
    throw new Error(registerData.error || '注册失败');
  }
  
  console.log('注册成功，用户:', registerData.user);
  
  // 2. 立即登录
  const loginResponse = await fetch('http://your-domain:21114/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      username,
      password,
      id: 'client-id',  // 需要提供客户端ID和UUID
      uuid: 'device-uuid'
    })
  });
  
  const loginData = await loginResponse.json();
  
  if (loginData.access_token) {
    localStorage.setItem('access_token', loginData.access_token);
    return loginData.access_token;
  } else {
    throw new Error(loginData.error || '登录失败');
  }
}

// 使用
try {
  const token = await registerAndLogin('newuser', 'mypassword123');
  console.log('已注册并登录，Token:', token);
} catch (error) {
  console.error('注册或登录失败:', error);
}
```

---

#### 2. 用户登录

**端点**: `POST /api/login`

**描述**: 用户登录，获取访问令牌

**请求体** (JSON):

```json
{
  "username": "string",      // 用户名（必填）
  "password": "string",       // 密码（必填）
  "id": "string",             // RustDesk 客户端ID（必填）
  "uuid": "string",           // 设备UUID（必填）
  "autoLogin": true,          // 是否自动登录（可选，默认true）
  "type": "string",           // 客户端类型（可选）
  "deviceInfo": {}            // 设备信息对象（可选）
}
```

**响应** (成功):

```json
{
  "access_token": "abc123...",  // 访问令牌，后续请求需要携带
  "type": "access_token",
  "user": {
    "name": "username"
  }
}
```

**响应** (失败):

```json
{
  "error": "帐号或密码错误！请重试，多次重试后将被锁定IP！"
}
```

**示例代码** (JavaScript):

```javascript
const response = await fetch('http://your-domain:21114/api/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    username: 'myuser',
    password: 'mypassword',
    id: 'client-id-123',
    uuid: 'device-uuid-456',
    autoLogin: true,
    type: 'client',
    deviceInfo: {
      platform: 'Windows',
      version: '1.2.3'
    }
  })
});

const data = await response.json();
if (data.access_token) {
  localStorage.setItem('access_token', data.access_token);
}
```

**示例代码** (Python):

```python
import requests

url = "http://your-domain:21114/api/login"
payload = {
    "username": "myuser",
    "password": "mypassword",
    "id": "client-id-123",
    "uuid": "device-uuid-456",
    "autoLogin": True,
    "type": "client",
    "deviceInfo": {
        "platform": "Windows",
        "version": "1.2.3"
    }
}

response = requests.post(url, json=payload)
data = response.json()
if 'access_token' in data:
    access_token = data['access_token']
    # 保存token供后续使用
```

---

#### 3. 用户登出

**端点**: `POST /api/logout`

**描述**: 登出用户，清除服务器端的 token

**请求体** (JSON):

```json
{
  "id": "string",    // RustDesk 客户端ID（必填）
  "uuid": "string"   // 设备UUID（必填）
}
```

**响应** (成功):

```json
{
  "code": 1
}
```

**响应** (失败):

```json
{
  "error": "异常请求！"
}
```

**示例代码**:

```javascript
const response = await fetch('http://your-domain:21114/api/logout', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    id: 'client-id-123',
    uuid: 'device-uuid-456'
  })
});

const data = await response.json();
if (data.code === 1) {
  localStorage.removeItem('access_token');
}
```

---

#### 4. 获取当前用户信息

**端点**: `POST /api/currentUser`

**描述**: 获取当前登录用户的信息和 token

**认证**: 需要 Bearer Token

**请求头**:

```
Authorization: Bearer <access_token>
```

**响应** (成功):

```json
{
  "access_token": "abc123...",
  "type": "access_token",
  "name": "username"
}
```

**响应** (失败/未认证):

```json
{}
```

**示例代码**:

```javascript
const access_token = localStorage.getItem('access_token');

const response = await fetch('http://your-domain:21114/api/currentUser', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${access_token}`,
    'Content-Type': 'application/json',
  }
});

const user = await response.json();
console.log(user.name); // 用户名
```

---

### 地址簿相关

#### 4. 获取地址簿

**端点**: `GET /api/ab`

**描述**: 获取用户的标签和设备列表（地址簿）

**认证**: 需要 Bearer Token

**请求头**:

```
Authorization: Bearer <access_token>
```

**响应** (成功):

```json
{
  "updated_at": "2025-01-15T10:30:00",
  "data": "{\"tags\":[\"标签1\",\"标签2\"],\"peers\":[{\"id\":\"peer-id-1\",\"username\":\"admin\",\"hostname\":\"DESKTOP-123\",\"alias\":\"我的电脑\",\"platform\":\"Windows\",\"tags\":[\"标签1\"],\"hash\":\"password-hash\"}],\"tag_colors\":{\"标签1\":16711680}}"
}
```

**注意**: `data` 字段是 JSON 字符串，需要再次解析

**解析后的数据结构**:

```json
{
  "tags": ["标签1", "标签2"],
  "peers": [
    {
      "id": "peer-id-1",           // 设备ID
      "username": "admin",          // 系统用户名
      "hostname": "DESKTOP-123",   // 主机名
      "alias": "我的电脑",          // 别名
      "platform": "Windows",       // 平台
      "tags": ["标签1"],           // 标签数组
      "hash": "password-hash"      // 连接密码hash
    }
  ],
  "tag_colors": {                  // 标签颜色映射
    "标签1": 16711680
  }
}
```

**响应** (失败):

```json
{
  "error": "拉取列表错误！"
}
```

**示例代码**:

```javascript
const access_token = localStorage.getItem('access_token');

const response = await fetch('http://your-domain:21114/api/ab', {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${access_token}`,
  }
});

const result = await response.json();
const addressBook = JSON.parse(result.data);
console.log(addressBook.peers);    // 设备列表
console.log(addressBook.tags);     // 标签列表
```

---

#### 5. 更新地址簿

**端点**: `POST /api/ab`

**描述**: 更新用户的标签和设备列表

**认证**: 需要 Bearer Token

**请求头**:

```
Authorization: Bearer <access_token>
```

**请求体** (JSON):

```json
{
  "data": "{\"tags\":[\"标签1\"],\"peers\":[{\"id\":\"peer-id\",\"username\":\"user\",\"hostname\":\"host\",\"alias\":\"别名\",\"platform\":\"Windows\",\"tags\":[\"标签1\"],\"hash\":\"pass\"}],\"tag_colors\":{\"标签1\":\"16711680\"}}"
}
```

**注意**: `data` 字段必须是 JSON 字符串

**响应**:

```json
{
  "code": 102,
  "data": "更新地址簿有误"
}
```

**示例代码**:

```javascript
const access_token = localStorage.getItem('access_token');

const addressBook = {
  tags: ["工作", "个人"],
  peers: [
    {
      id: "peer-id-123",
      username: "admin",
      hostname: "DESKTOP-123",
      alias: "办公室电脑",
      platform: "Windows",
      tags: ["工作"],
      hash: "password-hash"
    }
  ],
  tag_colors: {
    "工作": "16711680",  // 红色
    "个人": "65280"      // 绿色
  }
};

const response = await fetch('http://your-domain:21114/api/ab', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${access_token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    data: JSON.stringify(addressBook)
  })
});

const result = await response.json();
```

---

#### 6. 获取地址簿 (兼容性端点)

**端点**: `POST /api/ab/get`

**描述**: 兼容 x86-sciter 版本客户端的地址簿获取接口，实际调用 GET /api/ab

**认证**: 需要 Bearer Token

**用法**: 与 GET /api/ab 相同

---

### 设备管理

#### 7. 注册/更新设备信息

**端点**: `POST /api/sysinfo`

**描述**: 注册新设备或更新现有设备的系统信息。客户端安装为服务后，会定时发送设备信息。

**请求体** (JSON):

```json
{
  "id": "string",           // RustDesk 客户端ID（必填）
  "uuid": "string",         // 设备UUID（必填）
  "cpu": "string",          // CPU信息（必填）
  "hostname": "string",     // 主机名（必填）
  "memory": "string",       // 内存信息（必填）
  "os": "string",           // 操作系统（必填）
  "version": "string",       // 客户端版本（必填）
  "username": "string"       // 系统用户名（可选）
}
```

**响应** (成功):

```json
{
  "data": "ok"
}
```

**响应** (失败):

```json
{
  "error": "错误的提交方式！"
}
```

**示例代码**:

```javascript
const deviceInfo = {
  id: "client-id-123",
  uuid: "device-uuid-456",
  cpu: "Intel Core i7-9700K",
  hostname: "DESKTOP-ABC123",
  memory: "16GB",
  os: "Windows 10 Pro",
  version: "1.2.3",
  username: "Administrator"
};

const response = await fetch('http://your-domain:21114/api/sysinfo', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(deviceInfo)
});

const result = await response.json();
console.log(result.data); // "ok"
```

---

#### 8. 心跳保活

**端点**: `POST /api/heartbeat`

**描述**: 保持设备在线状态，更新设备IP地址，延长 token 有效期

**请求体** (JSON):

```json
{
  "id": "string",    // RustDesk 客户端ID（必填）
  "uuid": "string"   // 设备UUID（必填）
}
```

**响应**:

```json
{
  "data": "在线"
}
```

**说明**: 
- Token 有效期为 7200 秒（2小时）
- 通过心跳接口可以延长 token 有效期
- 同时会更新设备的 IP 地址

**示例代码**:

```javascript
// 定期发送心跳（建议每30-60秒发送一次）
setInterval(async () => {
  const response = await fetch('http://your-domain:21114/api/heartbeat', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      id: 'client-id-123',
      uuid: 'device-uuid-456'
    })
  });
  
  const result = await response.json();
  console.log('Heartbeat:', result.data);
}, 60000); // 每60秒发送一次
```

---

### 审计日志

#### 9. 提交审计日志

**端点**: `POST /api/audit`

**描述**: 提交连接日志或文件传输日志

**请求体** (JSON):

根据不同的 `action` 类型，请求体结构不同：

**1. 新建连接** (`action: "new"`):

```json
{
  "action": "new",
  "conn_id": "12345",
  "ip": "192.168.1.100",
  "id": "remote-peer-id",
  "session_id": "session-uuid",
  "uuid": "device-uuid"
}
```

**2. 关闭连接** (`action: "close"`):

```json
{
  "action": "close",
  "conn_id": "12345"
}
```

**3. 更新连接信息**:

```json
{
  "conn_id": "12345",
  "session_id": "session-uuid",
  "peer": ["peer-id-1", "peer-id-2"]
}
```

**4. 文件传输日志** (`is_file: true`):

```json
{
  "is_file": true,
  "path": "/path/to/file",
  "peer_id": "peer-id",
  "id": "remote-peer-id",
  "type": 1,
  "info": "{\"ip\":\"192.168.1.100\",\"files\":[[\"filename.txt\",1024]]}"
}
```

**响应**:

```json
{
  "code": 1,
  "data": "ok"
}
```

**示例代码**:

```javascript
// 记录新连接
const newConnection = {
  action: "new",
  conn_id: "conn-12345",
  ip: "192.168.1.100",
  id: "remote-peer-id",
  session_id: "session-uuid-456",
  uuid: "device-uuid-789"
};

await fetch('http://your-domain:21114/api/audit', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(newConnection)
});

// 记录连接关闭
const closeConnection = {
  action: "close",
  conn_id: "conn-12345"
};

await fetch('http://your-domain:21114/api/audit', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(closeConnection)
});
```

---

### 占位端点

#### 10. 用户端点

**端点**: `POST /api/users`

**描述**: 占位端点，始终返回成功

**响应**:

```json
{
  "code": 1,
  "data": "好的"
}
```

---

#### 11. 设备端点

**端点**: `POST /api/peers`

**描述**: 占位端点，始终返回成功

**响应**:

```json
{
  "code": 1,
  "data": "ok"
}
```

---

## 错误处理

### 常见错误码

| 错误信息 | 说明 | 解决方案 |
|---------|------|---------|
| `请求方式错误！请使用POST方式。` | 使用了 GET 方法 | 改用 POST 方法 |
| `当前未开放注册，请联系管理员！` | 系统未开放注册功能 | 联系管理员或等待系统开放注册 |
| `用户名已存在。` | 用户名已被注册 | 更换用户名 |
| `用户名不得小于3位。` | 用户名长度不符合要求 | 使用至少3个字符的用户名 |
| `密码长度不符合要求, 应在8~20位。` | 密码长度不符合要求 | 使用8-20个字符的密码 |
| `用户名不能为空。` | 未提供用户名 | 提供用户名 |
| `密码不能为空。` | 未提供密码 | 提供密码 |
| `请求数据格式错误！请使用JSON格式。` | 请求体格式错误 | 使用正确的JSON格式 |
| `帐号或密码错误！` | 用户名或密码不正确 | 检查凭据 |
| `拉取列表错误！` | Token 无效或过期 | 重新登录获取 token |
| `异常请求！` | 请求参数错误或用户不存在 | 检查请求参数 |
| `错误的提交方式！` | 使用了 GET 方法 | 改用 POST 方法 |

### 错误响应格式

```json
{
  "error": "错误信息描述"
}
```

---

## Token 管理

### Token 有效期

- **默认有效期**: 7200 秒（2小时）
- **延长方式**: 通过 `/api/heartbeat` 接口可以延长有效期
- **存储方式**: 客户端应安全存储 token，建议使用本地存储或加密存储

### Token 使用

所有需要认证的接口都需要在 HTTP Header 中携带 token:

```
Authorization: Bearer <access_token>
```

---

## 最佳实践

### 1. 认证流程

```javascript
// 1. 登录获取 token
const loginResponse = await fetch('/api/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username, password, id, uuid })
});
const { access_token } = await loginResponse.json();

// 2. 保存 token
localStorage.setItem('access_token', access_token);

// 3. 使用 token 进行后续请求
const headers = {
  'Authorization': `Bearer ${access_token}`,
  'Content-Type': 'application/json'
};
```

### 2. 定期心跳

```javascript
// 建议每30-60秒发送一次心跳
const heartbeatInterval = setInterval(async () => {
  try {
    await fetch('/api/heartbeat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, uuid })
    });
  } catch (error) {
    console.error('Heartbeat failed:', error);
    // Token 可能已过期，需要重新登录
    clearInterval(heartbeatInterval);
  }
}, 60000);
```

### 3. 错误处理

```javascript
async function apiCall(url, options) {
  try {
    const response = await fetch(url, options);
    const data = await response.json();
    
    if (data.error) {
      // 处理错误
      if (data.error.includes('拉取列表错误')) {
        // Token 过期，重新登录
        await reLogin();
      }
      throw new Error(data.error);
    }
    
    return data;
  } catch (error) {
    console.error('API call failed:', error);
    throw error;
  }
}
```

### 4. 地址簿同步

```javascript
// 获取地址簿
async function getAddressBook() {
  const token = localStorage.getItem('access_token');
  const response = await fetch('/api/ab', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const { data } = await response.json();
  return JSON.parse(data); // data 是 JSON 字符串
}

// 更新地址簿
async function updateAddressBook(addressBook) {
  const token = localStorage.getItem('access_token');
  const response = await fetch('/api/ab', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      data: JSON.stringify(addressBook) // 注意：需要双重 JSON.stringify
    })
  });
  return await response.json();
}
```

---

## 数据模型

### Peer (设备) 结构

```typescript
interface Peer {
  id: string;           // 设备ID (RustDesk ID)
  username: string;      // 系统用户名
  hostname: string;     // 主机名
  alias: string;        // 别名
  platform: string;     // 平台 (Windows, Linux, macOS等)
  tags: string[];       // 标签数组
  hash: string;         // 连接密码hash
}
```

### Tag (标签) 结构

```typescript
interface Tag {
  name: string;         // 标签名称
  color?: number;       // 标签颜色 (RGB数值)
}
```

### Address Book (地址簿) 结构

```typescript
interface AddressBook {
  tags: string[];                    // 标签列表
  peers: Peer[];                     // 设备列表
  tag_colors: { [key: string]: number };  // 标签颜色映射
}
```

---

## 测试工具

### 使用 curl 测试

```bash
# 登录
curl -X POST http://localhost:21114/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "testpass",
    "id": "client-123",
    "uuid": "uuid-456"
  }'

# 获取地址簿（需要替换 <token>）
curl -X GET http://localhost:21114/api/ab \
  -H "Authorization: Bearer <token>"

# 心跳
curl -X POST http://localhost:21114/api/heartbeat \
  -H "Content-Type: application/json" \
  -d '{
    "id": "client-123",
    "uuid": "uuid-456"
  }'
```

---

## 版本信息

- **API 版本**: v1.0.0
- **Django 版本**: 4.2+
- **最后更新**: 2025-01-XX

---

## 支持与反馈

如有问题或建议，请提交 Issue 或 Pull Request。

---

## 附录

### 常量定义

- **Token 有效期**: `EFFECTIVE_SECONDS = 7200` (2小时)
- **Salt**: `'xiaomo'` (用于 token 生成)

### 兼容性说明

- `/api/ab/get` 端点用于兼容 x86-sciter 版本的客户端
- 所有时间字段使用服务器本地时间（Asia/Shanghai）

