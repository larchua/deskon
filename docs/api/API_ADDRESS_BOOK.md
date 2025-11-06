# 地址簿（Address Book）API 文档

本文档详细说明了地址簿相关的所有 API 接口，包括标准模式和 Legacy 模式的端点。

## 基础信息

- **基础路径**: `/api/`
- **认证方式**: Bearer Token（在 HTTP Header 中传递）
- **请求格式**: JSON

## 认证方式

所有地址簿接口都需要在 HTTP Header 中传递认证令牌：

```
Authorization: Bearer <access_token>
```

其中 `access_token` 通过登录接口 `/api/login` 获取。

---

## 1. 获取地址簿（GET）

### 接口信息

- **URL**: `/api/ab`
- **方法**: `GET`
- **认证**: 需要 Bearer Token

### 请求头

```
Authorization: Bearer <access_token>
```

### 请求示例

```bash
curl -X GET "http://your-domain:21114/api/ab" \
  -H "Authorization: Bearer your_access_token_here"
```

### 响应格式

#### 成功响应

```json
{
    "updated_at": "2025-11-04 12:00:00",
    "data": "{\"tags\":[\"tag1\",\"tag2\"],\"peers\":[{\"id\":\"rid123\",\"username\":\"user\",\"hostname\":\"PC\",\"alias\":\"我的电脑\",\"platform\":\"windows\",\"tags\":[\"tag1\"],\"hash\":\"hash123\"}],\"tag_colors\":\"{\\\"tag1\\\":16711680}\"}"
}
```

**注意**: `data` 字段是一个 JSON 字符串，需要客户端进行二次解析。

解析后的 `data` 结构：

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
    "tag_colors": {
        "tag1": 16711680
    }
}
```

#### 失败响应

```json
{
    "error": "拉取列表错误！"
}
```

---

## 2. 保存地址簿（POST）

### 接口信息

- **URL**: `/api/ab`
- **方法**: `POST`
- **认证**: 需要 Bearer Token

### 请求头

```
Authorization: Bearer <access_token>
Content-Type: application/json
```

### 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| data | string | 是 | JSON 字符串格式的地址簿数据 |

### 请求体结构

`data` 字段是一个 JSON 字符串，其内容结构如下：

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

**字段说明**:

- `tags`: 标签名称数组
- `peers`: 设备列表数组
  - `id`: 设备ID (RustDesk ID)
  - `username`: 设备用户名
  - `hostname`: 主机名
  - `alias`: 别名
  - `platform`: 平台 (windows/linux/mac/android/ios)
  - `tags`: 设备标签数组
  - `hash`: 设备哈希值
- `tag_colors`: 标签颜色（JSON 字符串格式，键为标签名，值为颜色值）

### 请求示例

```bash
curl -X POST "http://your-domain:21114/api/ab" \
  -H "Authorization: Bearer your_access_token_here" \
  -H "Content-Type: application/json" \
  -d '{
    "data": "{\"tags\":[\"tag1\"],\"peers\":[{\"id\":\"rid123\",\"username\":\"user\",\"hostname\":\"PC\",\"alias\":\"我的电脑\",\"platform\":\"windows\",\"tags\":[\"tag1\"],\"hash\":\"hash123\"}],\"tag_colors\":\"{\\\"tag1\\\":16711680}\"}"
  }'
```

### JavaScript 示例

```javascript
const addressBookData = {
    tags: ["tag1", "tag2"],
    peers: [
        {
            id: "rid123",
            username: "user",
            hostname: "PC",
            alias: "我的电脑",
            platform: "windows",
            tags: ["tag1"],
            hash: "hash123"
        }
    ],
    tag_colors: JSON.stringify({
        "tag1": 16711680
    })
};

fetch('/api/ab', {
    method: 'POST',
    headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({
        data: JSON.stringify(addressBookData)
    })
})
.then(response => response.json())
.then(data => {
    if (data.code === 1) {
        console.log('地址簿保存成功');
    } else {
        console.error('保存失败:', data.error || data.msg);
    }
});
```

### 响应格式

#### 成功响应

```json
{
    "code": 1,
    "data": "更新地址簿成功"
}
```

#### 失败响应

```json
{
    "code": 0,
    "error": "错误信息",
    "msg": "详细错误信息"
}
```

### 错误码说明

| code | error/msg | 说明 |
|------|-----------|------|
| 1 | 更新地址簿成功 | 保存成功 |
| 0 | 请求数据格式错误 | JSON 格式错误 |
| 0 | 更新地址簿失败 | 数据库操作失败或其他错误 |

---

## 3. 兼容性端点

### 3.1 获取地址簿（兼容 x86-sciter 版）

- **URL**: `/api/ab/get`
- **方法**: `POST`
- **说明**: 兼容 x86-sciter 版本客户端，实际上会转换为 GET 请求处理

### 3.2 保存地址簿（兼容路径）

- **URL**: `/api/ab/save`
- **方法**: `POST`
- **说明**: 某些客户端可能使用此路径，实际处理逻辑与 `/api/ab` POST 相同

---

## 客户端集成指南

### 标准集成流程

```javascript
// 1. 登录获取 token
async function login(username, password) {
    const response = await fetch('/api/login', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            username: username,
            password: password,
            id: 'device_id',
            uuid: 'device_uuid'
        })
    });
    const data = await response.json();
    return data.access_token;
}

// 2. 获取地址簿
async function getAddressBook(accessToken) {
    const response = await fetch('/api/ab', {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${accessToken}`
        }
    });
    const data = await response.json();
    
    // 解析 data 字段（JSON 字符串）
    const addressBook = JSON.parse(data.data);
    return addressBook;
}

// 3. 保存地址簿
async function saveAddressBook(accessToken, addressBook) {
    const response = await fetch('/api/ab', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            data: JSON.stringify(addressBook)
        })
    });
    const data = await response.json();
    return data;
}

// 使用示例
const token = await login('username', 'password');
const addressBook = await getAddressBook(token);
// 修改 addressBook...
await saveAddressBook(token, addressBook);
```

---

## Legacy 模式支持

如果客户端提示 "Legacy mode"，可能需要检查：

1. **API 基础路径**: Legacy 模式可能不使用 `/api/` 前缀
   - 标准模式: `http://domain:21114/api/ab`
   - Legacy 模式: `http://domain:21114/ab` (如果服务器支持)

2. **认证方式**: Legacy 模式可能使用不同的认证方式
   - 检查是否需要在请求体中传递 token
   - 检查是否使用不同的 Header 名称

3. **响应格式**: Legacy 模式可能期望不同的响应格式

### 当前服务器支持的端点

本服务器支持以下所有端点：

- ✅ `GET /api/ab` - 获取地址簿
- ✅ `POST /api/ab` - 保存地址簿
- ✅ `POST /api/ab/get` - 兼容获取地址簿
- ✅ `POST /api/ab/save` - 兼容保存地址簿

---

## 常见问题

### Q1: 返回 404 错误

**可能原因**:
1. API 路径不正确（应该是 `/api/ab` 而不是 `/ab`）
2. 请求方法不正确（GET 用于获取，POST 用于保存）
3. 服务器路由配置问题

**解决方案**:
- 确认使用正确的路径: `http://your-domain:21114/api/ab`
- 确认请求方法: GET 获取，POST 保存
- 检查服务器日志查看实际请求路径

### Q2: 返回 "拉取列表错误！"

**可能原因**:
1. Token 无效或过期
2. Authorization Header 格式不正确

**解决方案**:
- 重新登录获取新的 token
- 确认 Header 格式: `Authorization: Bearer <token>`
- 检查 token 是否包含空格或特殊字符

### Q3: 保存失败 "请求数据格式错误"

**可能原因**:
1. `data` 字段不是有效的 JSON 字符串
2. 数据结构不符合要求

**解决方案**:
- 确保 `data` 字段是 JSON.stringify() 后的字符串
- 检查数据结构是否包含所有必需字段
- 验证 JSON 格式是否正确

### Q4: Legacy 模式错误

**可能原因**:
1. 客户端配置为 Legacy 模式
2. 服务器不支持 Legacy 模式的端点

**解决方案**:
- 检查客户端配置，确保使用标准 API 模式
- 如果必须使用 Legacy 模式，可能需要配置服务器支持根路径端点

---

## 调试建议

1. **启用服务器日志**: 查看实际接收到的请求路径和方法
2. **使用 curl 测试**: 先用 curl 测试 API 是否正常工作
3. **检查网络请求**: 使用浏览器开发者工具或抓包工具查看实际请求
4. **验证 Token**: 确保 token 有效且未过期

---

## 更新日志

- **2025-11-04**: 
  - 修复 POST 保存地址簿逻辑，成功时返回正确响应
  - 添加异常处理和错误信息
  - 添加 `/api/ab/save` 兼容端点
  - 完善文档说明

