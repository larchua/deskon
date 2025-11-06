# 客户端集成 API 文档

本文档为客户端开发者提供完整的 API 集成指南，包括标准模式和 Legacy 模式的支持。

## 服务器配置

- **标准 API 路径**: `http://your-domain:21114/api/`
- **Legacy 模式路径**: `http://your-domain:21114/` (直接根路径)
- **默认端口**: 21114

## 地址簿（Address Book）API

### 标准模式端点

#### 1. 获取地址簿

```
GET /api/ab
Authorization: Bearer <access_token>
```

**响应示例**:
```json
{
    "updated_at": "2025-11-04 12:00:00",
    "data": "{\"tags\":[],\"peers\":[],\"tag_colors\":\"{}\"}"
}
```

#### 2. 保存地址簿

```
POST /api/ab
Authorization: Bearer <access_token>
Content-Type: application/json

{
    "data": "{\"tags\":[\"tag1\"],\"peers\":[{\"id\":\"rid123\",\"username\":\"user\",\"hostname\":\"PC\",\"alias\":\"我的电脑\",\"platform\":\"windows\",\"tags\":[\"tag1\"],\"hash\":\"hash123\"}],\"tag_colors\":\"{\\\"tag1\\\":16711680}\"}"
}
```

**成功响应**:
```json
{
    "code": 1,
    "data": "更新地址簿成功"
}
```

### Legacy 模式端点（兼容旧版客户端）

Legacy 模式使用根路径，不需要 `/api/` 前缀：

#### 1. 获取地址簿

```
GET /ab
Authorization: Bearer <access_token>
```

#### 2. 保存地址簿

```
POST /ab
Authorization: Bearer <access_token>
Content-Type: application/json

{
    "data": "{\"tags\":[\"tag1\"],\"peers\":[...],\"tag_colors\":\"{}\"}"
}
```

#### 3. 兼容端点

```
POST /ab/get     # 兼容 x86-sciter 版获取地址簿
POST /ab/save    # 兼容某些客户端保存地址簿
```

## 完整端点列表

### 标准模式 (`/api/` 前缀)

| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/login` | POST | 用户登录 |
| `/api/logout` | POST | 用户登出 |
| `/api/ab` | GET/POST | 获取/保存地址簿 |
| `/api/ab/get` | POST | 兼容获取地址簿 |
| `/api/ab/save` | POST | 兼容保存地址簿 |
| `/api/currentUser` | POST | 获取当前用户信息 |
| `/api/sysinfo` | POST | 同步设备信息 |
| `/api/heartbeat` | POST | 心跳保持 |
| `/api/register` | POST | 用户注册 |
| `/api/membership/info` | POST | 获取会员信息 |
| `/api/user/change-password` | POST | 修改密码 |
| `/api/user/upload-avatar` | POST | 上传头像 |

### Legacy 模式（根路径）

| 端点 | 方法 | 功能 |
|------|------|------|
| `/login` | POST | 用户登录 |
| `/logout` | POST | 用户登出 |
| `/ab` | GET/POST | 获取/保存地址簿 |
| `/ab/get` | POST | 兼容获取地址簿 |
| `/ab/save` | POST | 兼容保存地址簿 |
| `/currentUser` | POST | 获取当前用户信息 |
| `/sysinfo` | POST | 同步设备信息 |
| `/heartbeat` | POST | 心跳保持 |
| `/register` | POST | 用户注册 |

## 认证方式

所有 API 请求都需要在 HTTP Header 中传递认证令牌：

```
Authorization: Bearer <access_token>
```

### 获取 Access Token

通过登录接口获取：

```json
POST /api/login
Content-Type: application/json

{
    "username": "your_username",
    "password": "your_password",
    "id": "device_id",
    "uuid": "device_uuid"
}
```

**响应**:
```json
{
    "access_token": "token_string",
    "type": "access_token",
    "user": {
        "name": "username",
        "avatar": "http://domain.com/media/avatars/xxx.jpg"
    }
}
```

## 地址簿数据结构

### 请求数据格式

```json
{
    "tags": ["tag1", "tag2"],
    "peers": [
        {
            "id": "rid123",
            "username": "user",
            "hostname": "PC",
            "alias": "我的电脑",
            "platform": "windows",
            "tags": ["tag1"],
            "hash": "hash123"
        }
    ],
    "tag_colors": "{\"tag1\":16711680}"
}
```

**注意**: 
- `data` 字段必须是 JSON 字符串（使用 `JSON.stringify()`）
- `tag_colors` 字段也是 JSON 字符串格式

### 响应数据格式

```json
{
    "updated_at": "2025-11-04 12:00:00",
    "data": "{\"tags\":[],\"peers\":[],\"tag_colors\":\"{}\"}"
}
```

**注意**: `data` 字段是 JSON 字符串，需要客户端进行二次解析。

## 客户端实现示例

### JavaScript/TypeScript

```typescript
class DeskonAPIClient {
    private baseURL: string;
    private accessToken: string | null = null;

    constructor(baseURL: string, legacyMode: boolean = false) {
        this.baseURL = legacyMode ? baseURL : `${baseURL}/api`;
    }

    // 登录
    async login(username: string, password: string, deviceId: string, deviceUuid: string): Promise<boolean> {
        const response = await fetch(`${this.baseURL}/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username,
                password,
                id: deviceId,
                uuid: deviceUuid
            })
        });

        const data = await response.json();
        if (data.access_token) {
            this.accessToken = data.access_token;
            return true;
        }
        return false;
    }

    // 获取地址簿
    async getAddressBook(): Promise<any> {
        if (!this.accessToken) {
            throw new Error('Not logged in');
        }

        const response = await fetch(`${this.baseURL}/ab`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${this.accessToken}`
            }
        });

        const data = await response.json();
        if (data.error) {
            throw new Error(data.error);
        }

        // 解析 data 字段
        return JSON.parse(data.data);
    }

    // 保存地址簿
    async saveAddressBook(addressBook: any): Promise<boolean> {
        if (!this.accessToken) {
            throw new Error('Not logged in');
        }

        const response = await fetch(`${this.baseURL}/ab`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.accessToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                data: JSON.stringify(addressBook)
            })
        });

        const data = await response.json();
        return data.code === 1;
    }
}

// 使用示例
const client = new DeskonAPIClient('http://your-domain:21114', false); // false = 标准模式
await client.login('username', 'password', 'device_id', 'device_uuid');
const addressBook = await client.getAddressBook();
// 修改 addressBook...
await client.saveAddressBook(addressBook);
```

### Rust (示例)

```rust
use reqwest::Client;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
struct AddressBook {
    tags: Vec<String>,
    peers: Vec<Peer>,
    tag_colors: String,
}

#[derive(Serialize, Deserialize)]
struct Peer {
    id: String,
    username: String,
    hostname: String,
    alias: String,
    platform: String,
    tags: Vec<String>,
    hash: String,
}

struct DeskonAPIClient {
    base_url: String,
    access_token: Option<String>,
    client: Client,
}

impl DeskonAPIClient {
    fn new(base_url: String, legacy_mode: bool) -> Self {
        let base = if legacy_mode {
            base_url
        } else {
            format!("{}/api", base_url)
        };
        
        Self {
            base_url: base,
            access_token: None,
            client: Client::new(),
        }
    }

    async fn login(&mut self, username: &str, password: &str, device_id: &str, device_uuid: &str) -> Result<(), Box<dyn std::error::Error>> {
        let response = self.client
            .post(&format!("{}/login", self.base_url))
            .json(&serde_json::json!({
                "username": username,
                "password": password,
                "id": device_id,
                "uuid": device_uuid
            }))
            .send()
            .await?;

        let data: serde_json::Value = response.json().await?;
        if let Some(token) = data.get("access_token").and_then(|v| v.as_str()) {
            self.access_token = Some(token.to_string());
            Ok(())
        } else {
            Err("Login failed".into())
        }
    }

    async fn get_address_book(&self) -> Result<AddressBook, Box<dyn std::error::Error>> {
        let token = self.access_token.as_ref().ok_or("Not logged in")?;
        
        let response = self.client
            .get(&format!("{}/ab", self.base_url))
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await?;

        let data: serde_json::Value = response.json().await?;
        let data_str = data.get("data")
            .and_then(|v| v.as_str())
            .ok_or("Invalid response")?;
        
        let address_book: AddressBook = serde_json::from_str(data_str)?;
        Ok(address_book)
    }

    async fn save_address_book(&self, address_book: &AddressBook) -> Result<(), Box<dyn std::error::Error>> {
        let token = self.access_token.as_ref().ok_or("Not logged in")?;
        
        let data_json = serde_json::to_string(address_book)?;
        let response = self.client
            .post(&format!("{}/ab", self.base_url))
            .header("Authorization", format!("Bearer {}", token))
            .json(&serde_json::json!({
                "data": data_json
            }))
            .send()
            .await?;

        let result: serde_json::Value = response.json().await?;
        if result.get("code").and_then(|v| v.as_i64()) == Some(1) {
            Ok(())
        } else {
            Err("Save failed".into())
        }
    }
}
```

## 错误处理

### 常见错误码

| 错误 | HTTP状态 | 说明 |
|------|----------|------|
| 404 | 404 Not Found | 端点不存在（检查路径是否正确） |
| 401 | 401 Unauthorized | Token 无效或过期 |
| 400 | 400 Bad Request | 请求数据格式错误 |
| 500 | 500 Internal Server Error | 服务器内部错误 |

### 错误响应格式

```json
{
    "code": 0,
    "error": "错误信息",
    "msg": "详细错误信息"
}
```

## 调试建议

1. **检查端点路径**: 确认使用标准模式 (`/api/ab`) 还是 Legacy 模式 (`/ab`)
2. **验证 Token**: 确保 token 有效且格式正确
3. **查看服务器日志**: 检查实际接收到的请求
4. **使用 curl 测试**: 先用命令行工具测试 API

### curl 测试示例

```bash
# 登录
curl -X POST "http://your-domain:21114/api/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123","id":"device1","uuid":"uuid1"}'

# 获取地址簿（使用返回的 token）
curl -X GET "http://your-domain:21114/api/ab" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# 保存地址簿
curl -X POST "http://your-domain:21114/api/ab" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"data":"{\"tags\":[],\"peers\":[],\"tag_colors\":\"{}\"}"}'
```

## 注意事项

1. **数据格式**: `data` 字段必须是 JSON 字符串，不是 JSON 对象
2. **认证**: 所有需要认证的接口都必须传递 `Authorization: Bearer <token>` Header
3. **Legacy 模式**: 如果客户端提示 "Legacy mode"，使用根路径端点（不带 `/api/` 前缀）
4. **错误处理**: 始终检查响应中的 `code` 字段，`code: 1` 表示成功，`code: 0` 表示失败

---

**最后更新**: 2025-11-04
**文档版本**: 1.0

