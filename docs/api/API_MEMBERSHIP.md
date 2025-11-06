# 会员信息 API 文档

## 获取会员信息

客户端可以通过此API获取当前登录用户的会员信息，包括用户等级、订阅状态、权限配置等。

### 接口地址

```
POST /api/membership/info
```

### 认证方式

需要在请求头中携带 `Authorization` 或请求体中提供 `access_token`：

**方式1：请求头（推荐）**
```
Authorization: Bearer <access_token>
```

**方式2：请求体**
```json
{
  "access_token": "<access_token>"
}
```

### 请求示例

```javascript
// JavaScript 示例
const response = await fetch('http://your-domain:21114/api/membership/info', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer your_access_token_here'
  }
});

const data = await response.json();
console.log(data);
```

```python
# Python 示例
import requests

url = 'http://your-domain:21114/api/membership/info'
headers = {
    'Authorization': 'Bearer your_access_token_here',
    'Content-Type': 'application/json'
}
response = requests.post(url, headers=headers)
data = response.json()
print(data)
```

### 响应格式

#### 成功响应

```json
{
  "code": 1,
  "user_level": "普通用户",
  "level_name": "normal",
  "subscription": {
    "plan_type": "monthly",
    "plan_name": "月度订阅",
    "start_time": "2024-01-01 00:00:00",
    "end_time": "2024-02-01 00:00:00",
    "days_remaining": 15,
    "is_active": true
  },
  "permissions": {
    "max_devices": 50,
    "max_connections": 20,
    "daily_usage_limit_minutes": null
  },
  "has_valid_subscription": true
}
```

#### 未订阅用户响应

```json
{
  "code": 1,
  "user_level": "普通用户",
  "level_name": "normal",
  "subscription": null,
  "permissions": {
    "max_devices": 10,
    "max_connections": 5,
    "daily_usage_limit_minutes": 60
  },
  "has_valid_subscription": false
}
```

#### 错误响应

```json
{
  "error": "未授权，请先登录"
}
```

### 响应字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `code` | integer | 响应代码，1表示成功 |
| `user_level` | string | 用户等级显示名称（普通用户、月度会员、季度会员、年费会员） |
| `level_name` | string | 用户等级标识（normal、monthly、quarterly、yearly） |
| `subscription` | object/null | 订阅信息，未订阅时为null |
| `subscription.plan_type` | string | 订阅类型（monthly、quarterly、yearly） |
| `subscription.plan_name` | string | 订阅计划名称 |
| `subscription.start_time` | string | 订阅开始时间 |
| `subscription.end_time` | string | 订阅结束时间 |
| `subscription.days_remaining` | integer | 剩余天数 |
| `subscription.is_active` | boolean | 是否有效 |
| `permissions` | object | 权限配置 |
| `permissions.max_devices` | integer | 最大设备数 |
| `permissions.max_connections` | integer | 最大并发连接数 |
| `permissions.daily_usage_limit_minutes` | integer/null | 每日使用时长限制（分钟），null表示无限制 |
| `has_valid_subscription` | boolean | 是否有有效订阅 |

### 用户等级说明

系统根据用户的订阅状态自动分配用户等级：

- **普通用户 (normal)**: 未订阅用户的默认等级
  - 每日使用时长限制：60分钟
  - 最大设备数：10
  - 最大并发连接数：5

- **月度会员 (monthly)**: 拥有有效的月度订阅
  - 无使用时长限制
  - 最大设备数：50
  - 最大并发连接数：20

- **季度会员 (quarterly)**: 拥有有效的季度订阅
  - 无使用时长限制
  - 最大设备数：100
  - 最大并发连接数：50

- **年费会员 (yearly)**: 拥有有效的年度订阅
  - 无使用时长限制
  - 最大设备数：200
  - 最大并发连接数：100

### 使用建议

1. **定期查询**: 客户端应在应用启动时和定期（如每小时）查询会员信息，确保权限数据是最新的
2. **权限检查**: 根据返回的 `permissions` 字段限制用户操作（如设备数量、连接数）
3. **时长限制**: 对于普通用户，根据 `daily_usage_limit_minutes` 实现使用时长限制
4. **订阅提醒**: 当 `days_remaining` 小于7天时，提示用户续费

### 错误处理

- **401 未授权**: 检查 `access_token` 是否有效
- **用户不存在**: 检查token对应的用户是否已被删除
- **网络错误**: 实现重试机制

### 集成示例

```javascript
class MembershipManager {
  constructor(apiBaseUrl, accessToken) {
    this.apiBaseUrl = apiBaseUrl;
    this.accessToken = accessToken;
    this.membershipInfo = null;
  }
  
  async fetchMembershipInfo() {
    try {
      const response = await fetch(`${this.apiBaseUrl}/api/membership/info`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json'
        }
      });
      const data = await response.json();
      if (data.code === 1) {
        this.membershipInfo = data;
        return data;
      } else {
        throw new Error(data.error || '获取会员信息失败');
      }
    } catch (error) {
      console.error('获取会员信息失败:', error);
      throw error;
    }
  }
  
  canUseDevice() {
    if (!this.membershipInfo) return false;
    // 检查设备数量限制（需要客户端自己维护设备数量）
    return true;
  }
  
  canMakeConnection() {
    if (!this.membershipInfo) return false;
    // 检查并发连接数限制
    return true;
  }
  
  getDailyUsageLimit() {
    if (!this.membershipInfo) return 60; // 默认60分钟
    return this.membershipInfo.permissions.daily_usage_limit_minutes || null;
  }
  
  isPremiumUser() {
    if (!this.membershipInfo) return false;
    return this.membershipInfo.has_valid_subscription;
  }
}

// 使用示例
const membershipManager = new MembershipManager('http://your-domain:21114', 'your_token');
await membershipManager.fetchMembershipInfo();
console.log('用户等级:', membershipManager.membershipInfo.user_level);
console.log('每日限制:', membershipManager.getDailyUsageLimit());
```

