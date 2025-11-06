# 用户资料管理 API 文档

本文档描述了用户资料管理相关的 API 接口，包括修改密码和上传头像功能。

## 基础信息

- **基础路径**: `/api/`
- **认证方式**: 使用 `access_token` 进行身份验证
- **请求格式**: JSON (修改密码) 或 multipart/form-data (上传头像)

---

## 1. 修改密码

### 接口信息

- **URL**: `/api/user/change-password`
- **方法**: `POST`
- **认证**: 需要 `access_token`

### 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| access_token | string | 是 | 用户访问令牌 |
| old_password | string | 是 | 旧密码 |
| new_password | string | 是 | 新密码（8-20位） |

### 请求示例

```json
{
    "access_token": "your_access_token_here",
    "old_password": "old_password_123",
    "new_password": "new_password_456"
}
```

### 响应格式

#### 成功响应

```json
{
    "code": 1,
    "msg": "密码修改成功。"
}
```

#### 失败响应

```json
{
    "code": 0,
    "msg": "错误信息"
}
```

### 错误码说明

| code | msg | 说明 |
|------|-----|------|
| 0 | 请求方式错误！请使用POST方式。 | 请求方法不正确 |
| 0 | 请求数据格式错误！请使用JSON格式。 | JSON格式错误 |
| 0 | 缺少access_token参数。 | 未提供token |
| 0 | 旧密码和新密码不能为空。 | 参数缺失 |
| 0 | 新密码长度不符合要求, 应在8~20位。 | 密码长度不符合要求 |
| 0 | 无效的access_token。 | token无效或已过期 |
| 0 | 用户不存在。 | 用户不存在 |
| 0 | 旧密码错误。 | 旧密码验证失败 |
| 0 | 新密码不能与旧密码相同。 | 新旧密码相同 |
| 1 | 密码修改成功。 | 修改成功 |

---

## 2. 上传/修改头像

### 接口信息

- **URL**: `/api/user/upload-avatar`
- **方法**: `POST`
- **认证**: 需要 `access_token`
- **Content-Type**: `multipart/form-data`

### 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| access_token | string | 是 | 用户访问令牌（可通过POST参数或Authorization头传递） |
| avatar | file | 是 | 头像图片文件 |

### 文件要求

- **支持格式**: JPG, JPEG, PNG, GIF
- **文件大小**: 最大 5MB
- **MIME类型**: `image/jpeg`, `image/jpg`, `image/png`, `image/gif`

### 请求示例

#### 方式1: 使用 POST 参数

```bash
curl -X POST "http://your-domain.com/api/user/upload-avatar" \
  -H "Content-Type: multipart/form-data" \
  -F "access_token=your_access_token_here" \
  -F "avatar=@/path/to/avatar.jpg"
```

#### 方式2: 使用 Authorization 头

```bash
curl -X POST "http://your-domain.com/api/user/upload-avatar" \
  -H "Authorization: Bearer your_access_token_here" \
  -H "Content-Type: multipart/form-data" \
  -F "avatar=@/path/to/avatar.jpg"
```

#### JavaScript 示例

```javascript
const formData = new FormData();
formData.append('access_token', 'your_access_token_here');
formData.append('avatar', fileInput.files[0]);

fetch('/api/user/upload-avatar', {
    method: 'POST',
    body: formData
})
.then(response => response.json())
.then(data => {
    if (data.code === 1) {
        console.log('头像上传成功:', data.data.avatar_url);
    } else {
        console.error('上传失败:', data.msg);
    }
});
```

### 响应格式

#### 成功响应

```json
{
    "code": 1,
    "msg": "头像上传成功。",
    "data": {
        "avatar_url": "http://your-domain.com/media/avatars/user_123_avatar.jpg"
    }
}
```

#### 失败响应

```json
{
    "code": 0,
    "msg": "错误信息"
}
```

### 错误码说明

| code | msg | 说明 |
|------|-----|------|
| 0 | 请求方式错误！请使用POST方式。 | 请求方法不正确 |
| 0 | 缺少access_token参数。 | 未提供token |
| 0 | 无效的access_token。 | token无效或已过期 |
| 0 | 用户不存在。 | 用户不存在 |
| 0 | 请选择要上传的头像文件。 | 未上传文件 |
| 0 | 不支持的文件类型，仅支持JPG、PNG、GIF格式。 | 文件格式不支持 |
| 0 | 文件大小不能超过5MB。 | 文件过大 |
| 1 | 头像上传成功。 | 上传成功 |

---

## 3. 获取用户信息（登录接口）

登录接口 (`/api/login`) 现在会返回用户的头像信息（如果已设置）。

### 响应示例

```json
{
    "access_token": "token_string",
    "type": "access_token",
    "user": {
        "name": "username",
        "avatar": "http://your-domain.com/media/avatars/user_123_avatar.jpg"
    }
}
```

如果用户未设置头像，`avatar` 字段将不存在。

---

## 注意事项

1. **Token 有效期**: `access_token` 的有效期由系统配置决定，过期后需要重新登录获取新token。

2. **头像存储**: 
   - 头像文件存储在服务器的 `media/avatars/` 目录下
   - 访问URL格式: `http://your-domain.com/media/avatars/filename.jpg`
   - 上传新头像时会自动删除旧头像文件

3. **密码安全**:
   - 密码以加密形式存储在数据库中
   - 密码长度必须在 8-20 位之间
   - 新密码不能与旧密码相同

4. **文件上传**:
   - 建议客户端在上传前对图片进行压缩和裁剪
   - 服务器会自动处理文件存储和URL生成
   - 删除旧头像时如果出现错误不会影响新头像的上传

5. **开发环境 vs 生产环境**:
   - 开发环境 (DEBUG=True): 媒体文件通过Django自动服务
   - 生产环境 (DEBUG=False): 需要配置Web服务器（如Nginx）来服务媒体文件

---

## 客户端集成示例

### 完整的用户资料管理流程

```javascript
// 1. 登录获取token
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
    return data.access_token; // 保存token
}

// 2. 修改密码
async function changePassword(accessToken, oldPassword, newPassword) {
    const response = await fetch('/api/user/change-password', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            access_token: accessToken,
            old_password: oldPassword,
            new_password: newPassword
        })
    });
    const data = await response.json();
    return data;
}

// 3. 上传头像
async function uploadAvatar(accessToken, avatarFile) {
    const formData = new FormData();
    formData.append('access_token', accessToken);
    formData.append('avatar', avatarFile);
    
    const response = await fetch('/api/user/upload-avatar', {
        method: 'POST',
        body: formData
    });
    const data = await response.json();
    return data;
}

// 使用示例
const token = await login('username', 'password');
await changePassword(token, 'old_pwd', 'new_pwd');
await uploadAvatar(token, fileInput.files[0]);
```

---

## 更新日志

- **2025-11-04**: 
  - 新增修改密码API (`/api/user/change-password`)
  - 新增上传头像API (`/api/user/upload-avatar`)
  - 更新登录接口，返回用户头像信息
  - 添加用户头像字段到数据库模型

