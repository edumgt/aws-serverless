# 🚀 AWS 서버리스 배포 완전 가이드 — Node.js · Python · Java + API Gateway + AWS CLI

> **AWS Lambda와 Amazon API Gateway를 활용한 서버리스 함수 배포 실습 튜토리얼**  
> Node.js, Python, Java — AWS 콘솔과 AWS CLI 모두 다룹니다.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-20.x-green?logo=node.js)](nodejs/)
[![Python](https://img.shields.io/badge/Python-3.12-blue?logo=python)](python/)
[![Java](https://img.shields.io/badge/Java-17-red?logo=openjdk)](java/)
[![Serverless](https://img.shields.io/badge/Serverless-Framework-fd5750?logo=serverless)](https://www.serverless.com/)
[![AWS](https://img.shields.io/badge/AWS-Lambda%20%7C%20API%20GW-FF9900?logo=amazonaws)](https://aws.amazon.com/)

---

## 📖 목차

1. [개요](#개요)
2. [아키텍처](#아키텍처)
3. [사전 준비](#사전-준비)
4. [AWS CLI 설치 및 설정](#aws-cli-설치-및-설정)
5. [Node.js 서버리스 배포](#nodejs-서버리스-배포)
6. [Python 서버리스 배포](#python-서버리스-배포)
7. [Java 서버리스 배포](#java-서버리스-배포)
8. [API Gateway 연동](#api-gateway-연동)
9. [권한 오류 해결 가이드](#권한-오류-해결-가이드)
10. [AWS CLI 명령어 모음](#aws-cli-명령어-모음)
11. [Well-Architected 참고](#well-architected-참고)
12. [후원 안내](#후원-안내)

---

## 개요

이 저장소는 **AWS Lambda와 Amazon API Gateway**를 활용한 서버리스 배포를 배우기 위한 **교육용 실습 레포**입니다.  
콘솔 스크린샷 기반의 단계별 가이드와 AWS CLI 명령어를 함께 제공합니다.

| 디렉터리 | 런타임 | 배포 설정 파일 |
|---|---|---|
| 루트(`/`) | Node.js 18/20.x | `serverless.yaml` |
| `python/` | Python 3.12 | `python/serverless.yaml` |
| `java/` | Java 17 | `java/serverless.yaml` |

### 서버리스란?

Node.js, Python, Java에서 말하는 **Serverless**는 서버가 없다는 뜻이 아니라,  
**서버 인프라 관리를 직접 하지 않고 코드 실행에만 집중**하는 개발 방식입니다.

| 기능 | 설명 |
|---|---|
| 서버 없이 코드 실행 | Express/Flask/Spring 없이 핸들러 함수만 실행 |
| 요청마다 자동 인스턴스 | 요청 시 Lambda 자동 실행 |
| 사용량 기반 과금 | 초 단위 과금, 항상 켜둘 필요 없음 |
| 인프라 자동 구성 | Serverless Framework으로 API Gateway, IAM, Lambda 자동 설정 |
| 배포 자동화 | `serverless deploy` 한 줄로 배포 |

| 항목 | 전통적인 서버 (EC2 + Express 등) | 서버리스 (Lambda + API Gateway) |
|---|---|---|
| 서버 유지 | EC2, PM2 등 상시 실행 | 요청 시 자동 실행 |
| 비용 | 항상 켜두므로 요금 발생 | 호출 시만 과금 |
| 배포 | 수동 (ssh, git pull, 재시작) | 자동 (`serverless deploy`) |
| 관리 | 인스턴스/보안그룹/LB 직접 관리 | AWS가 관리 (IAM, 보안, 스케일) |
| 성능 튜닝 | 직접 조절 필요 | 동시성 자동, 콜드스타트 주의 |

---

## 아키텍처

```
클라이언트 (브라우저 / curl / Postman)
        │  HTTP GET /hello?name=...
        ▼
 ┌──────────────────────┐
 │  Amazon API Gateway  │  ← REST API 또는 HTTP API
 └──────────┬───────────┘
            │  Lambda Proxy 통합
            ▼
 ┌──────────────────────┐
 │    AWS Lambda        │  ← Node.js / Python / Java 핸들러
 └──────────┬───────────┘
            │  로그/메트릭
            ▼
 ┌──────────────────────┐
 │  Amazon CloudWatch   │
 └──────────────────────┘
```

---

## 사전 준비

| 도구 | 버전 | 설치 방법 |
|---|---|---|
| AWS 계정 | — | [무료 가입](https://aws.amazon.com/free/) |
| AWS CLI | v2 | [아래 설치 가이드](#aws-cli-설치-및-설정) |
| Node.js | 18+ | [nodejs.org](https://nodejs.org/) |
| Python | 3.12 | [python.org](https://www.python.org/) |
| Java (JDK) | 17 | [adoptium.net](https://adoptium.net/) |
| Maven | 3.8+ | [maven.apache.org](https://maven.apache.org/) |
| Serverless Framework | 3.x | `npm install -g serverless@3` |

---

## AWS CLI 설치 및 설정

### 1. AWS CLI v2 설치

**macOS / Linux**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

**Windows (PowerShell)**
```powershell
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
aws --version
```

### 2. 자격 증명 설정

```bash
aws configure
# AWS Access Key ID     [None]: <YOUR_ACCESS_KEY>
# AWS Secret Access Key [None]: <YOUR_SECRET_KEY>
# Default region name   [None]: ap-northeast-2
# Default output format [None]: json
```

> 💡 **보안 팁:** 운영 환경에서는 장기 자격 증명(Access Key) 대신 IAM Role 또는 AWS SSO를 사용하세요.

### 3. 설정 확인

```bash
aws sts get-caller-identity
```

---

## Node.js 서버리스 배포

### 핸들러 코드

```javascript
// handler.js
module.exports.hello = async (event) => {
  const name = event.queryStringParameters?.name || "World";
  return {
    statusCode: 200,
    body: JSON.stringify({ message: `Hello, ${name}!`, language: "Node.js" }),
  };
};
```

### 콘솔 배포 절차

1. **AWS 콘솔 → Lambda → 함수 생성** 클릭
2. **새로 작성** 선택
3. **런타임**: `Node.js 20.x`
4. 코드 탭에 위 핸들러 코드 붙여넣기
5. **배포** → **테스트** 실행

![Lambda 함수 생성 결과](docs/images/image-1.png)

### AWS CLI 배포

**1단계 — 코드 압축**
```bash
# Linux / macOS
zip function.zip index.js

# Windows PowerShell
Compress-Archive -Path index.js -DestinationPath function.zip
```

**2단계 — Lambda 함수 생성**
```bash
aws lambda create-function \
  --function-name edumgt-lambda-nodejs \
  --runtime nodejs20.x \
  --role arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME> \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --region ap-northeast-2
```

**3단계 — 코드 변경 후 업데이트**
```bash
aws lambda update-function-code \
  --function-name edumgt-lambda-nodejs \
  --zip-file fileb://function.zip \
  --region ap-northeast-2
```

**4단계 — 함수 호출 테스트**
```bash
aws lambda invoke \
  --function-name edumgt-lambda-nodejs \
  --payload '{"queryStringParameters":{"name":"Alice"}}' \
  --cli-binary-format raw-in-base64-out \
  response.json
cat response.json
```

### Serverless Framework 배포

```bash
# Serverless Framework v3 설치 (v4는 별도 인증 필요)
npm install -g serverless@3

# 배포 (루트의 serverless.yaml 사용)
serverless deploy

# 삭제
serverless remove
```

`serverless.yaml` (루트):
```yaml
service: hello-api

provider:
  name: aws
  runtime: nodejs18.x
  region: ap-northeast-2

functions:
  hello:
    handler: handler.hello
    events:
      - http:
          path: hello
          method: get
```

---

## Python 서버리스 배포

### 핸들러 코드

```python
# python/handler.py
import json

def hello(event, context):
    query_params = event.get("queryStringParameters") or {}
    name = query_params.get("name", "World")
    body = {"message": f"Hello, {name}!", "language": "Python"}
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
```

### 콘솔 배포 절차

1. **AWS 콘솔 → Lambda → 함수 생성**
2. **새로 작성** 선택
3. **런타임**: `Python 3.12`
4. 코드 탭에 위 핸들러 코드 붙여넣기
5. **핸들러** 설정: `handler.hello`
6. **배포** → **테스트** 이벤트:
   ```json
   { "queryStringParameters": { "name": "Alice" } }
   ```

### AWS CLI 배포

**1단계 — 코드 압축**
```bash
cd python
zip function.zip handler.py
```

**2단계 — Lambda 함수 생성**
```bash
aws lambda create-function \
  --function-name edumgt-lambda-python \
  --runtime python3.12 \
  --role arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME> \
  --handler handler.hello \
  --zip-file fileb://function.zip \
  --region ap-northeast-2
```

**3단계 — 함수 호출 테스트**
```bash
aws lambda invoke \
  --function-name edumgt-lambda-python \
  --payload '{"queryStringParameters":{"name":"Alice"}}' \
  --cli-binary-format raw-in-base64-out \
  response.json
cat response.json
```

**4단계 — 코드 업데이트**
```bash
aws lambda update-function-code \
  --function-name edumgt-lambda-python \
  --zip-file fileb://function.zip \
  --region ap-northeast-2
```

### Serverless Framework 배포

```bash
cd python
serverless deploy
```

`python/serverless.yaml`:
```yaml
service: hello-api-python

provider:
  name: aws
  runtime: python3.12
  region: ap-northeast-2

functions:
  hello:
    handler: handler.hello
    events:
      - http:
          path: hello
          method: get
          cors: true
```

---

## Java 서버리스 배포

### 핸들러 코드

```java
// java/src/main/java/com/example/HelloHandler.java
package com.example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import java.util.Map;
import java.util.HashMap;

public class HelloHandler
        implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    @Override
    public APIGatewayProxyResponseEvent handleRequest(
            APIGatewayProxyRequestEvent input, Context context) {
        Map<String, String> params = input.getQueryStringParameters();
        String name = (params != null && params.containsKey("name")) ? params.get("name") : "World";

        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Type", "application/json");
        String body = String.format("{\"message\": \"Hello, %s!\", \"language\": \"Java\"}", name);

        return new APIGatewayProxyResponseEvent()
                .withStatusCode(200).withHeaders(headers).withBody(body);
    }
}
```

### 콘솔 배포 절차

1. **Maven으로 JAR 빌드**:
   ```bash
   cd java
   mvn package
   # 결과물: target/hello-lambda-1.0-SNAPSHOT.jar
   ```
2. **AWS 콘솔 → Lambda → 함수 생성**
3. **새로 작성** 선택
4. **런타임**: `Java 17`
5. **코드** 탭 → **.jar 파일 업로드**
6. **핸들러** 설정: `com.example.HelloHandler`
7. **메모리**: 최소 `512 MB` (Java 콜드스타트 고려)
8. **배포** → **테스트** 실행

### AWS CLI 배포

**1단계 — JAR 빌드**
```bash
cd java
mvn package
```

**2단계 — Lambda 함수 생성**
```bash
aws lambda create-function \
  --function-name edumgt-lambda-java \
  --runtime java17 \
  --role arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME> \
  --handler com.example.HelloHandler \
  --zip-file fileb://target/hello-lambda-1.0-SNAPSHOT.jar \
  --memory-size 512 \
  --timeout 15 \
  --region ap-northeast-2
```

**3단계 — 함수 호출 테스트**
```bash
aws lambda invoke \
  --function-name edumgt-lambda-java \
  --payload '{"queryStringParameters":{"name":"Alice"}}' \
  --cli-binary-format raw-in-base64-out \
  response.json
cat response.json
```

### Serverless Framework 배포

```bash
cd java
mvn package        # 먼저 JAR 빌드
serverless deploy
```

`java/serverless.yaml`:
```yaml
service: hello-api-java

provider:
  name: aws
  runtime: java17
  region: ap-northeast-2

package:
  artifact: target/hello-lambda-1.0-SNAPSHOT.jar

functions:
  hello:
    handler: com.example.HelloHandler
    memorySize: 512
    timeout: 15
    events:
      - http:
          path: hello
          method: get
          cors: true
```

---

## API Gateway 연동

### 방법 A — AWS 콘솔

1. **AWS 콘솔 → API Gateway** 이동
2. **REST API → 구축** 선택
3. 새 **리소스** `/hello` 생성
4. **GET 메서드** 추가 → 통합 유형: **Lambda 함수**, **Lambda 프록시 통합** 활성화
5. **API 배포** → 새 **스테이지** 생성 (예: `dev`)
6. **호출 URL** 확인:
   ```
   https://<API_ID>.execute-api.ap-northeast-2.amazonaws.com/dev/hello?name=Alice
   ```

![API Gateway 설정 화면](docs/images/image.png)
![Lambda 함수 연결](docs/images/image-2.png)
![Lambda 함수 연결 상세](docs/images/image-3.png)
![리소스 생성](docs/images/image-5.png)
![메서드 생성 입력](docs/images/image-8.png)
![메서드 생성 확인](docs/images/image-9.png)
![GET 메서드 Lambda 통합](docs/images/image-10.png)
![배포 URL 확인](docs/images/image-11.png)
![스테이지 생성](docs/images/image-12.png)
![재배포](docs/images/image-13.png)

### 방법 B — AWS CLI

```bash
# 1. REST API 생성
API_ID=$(aws apigateway create-rest-api \
  --name "hello-api" \
  --query 'id' --output text)

# 2. 루트 리소스 ID 조회
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --query 'items[?path==`/`].id' --output text)

# 3. /hello 리소스 생성
RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part hello \
  --query 'id' --output text)

# 4. GET 메서드 생성
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE

# 5. Lambda 통합 설정
LAMBDA_ARN="arn:aws:lambda:ap-northeast-2:<ACCOUNT_ID>:function:edumgt-lambda-nodejs"
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:ap-northeast-2:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"

# 6. API Gateway의 Lambda 호출 권한 부여
aws lambda add-permission \
  --function-name edumgt-lambda-nodejs \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:ap-northeast-2:<ACCOUNT_ID>:${API_ID}/*/*"

# 7. 스테이지 배포
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev

echo "엔드포인트: https://${API_ID}.execute-api.ap-northeast-2.amazonaws.com/dev/hello"
```

### 방법 C — Serverless Framework (자동)

각 언어 디렉터리의 `serverless.yaml`에 `http` 이벤트가 정의되어 있으면,  
`serverless deploy` 실행 시 API Gateway가 자동으로 생성/연결됩니다.  
배포 완료 후 엔드포인트 URL이 터미널에 출력됩니다.

---

## 권한 오류 해결 가이드

### CloudFormation 권한 오류
```
User ... is not authorized to perform: cloudformation:CreateChangeSet
```
**해결:** IAM → 사용자 → 권한 → `AWSCloudFormationFullAccess` 정책 추가

![CloudFormation 권한 추가](docs/images/image-15.png)
![정책 확인](docs/images/image-16.png)

### API Gateway 권한 오류
```
... not authorized to perform: apigateway:PUT ...
```
**해결:** `AmazonAPIGatewayAdministrator` 정책 추가

![API Gateway 권한](docs/images/image-17.png)
![API Gateway 권한 상세](docs/images/image-18.png)

### CloudFormation 스택 롤백 오류
```
Stack ... is in UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS state
```
**해결:** 스택 삭제 후 재시도
```bash
aws cloudformation delete-stack --stack-name hello-api-dev
```

![스택 에러](docs/images/image-19.png)
![삭제 성공](docs/images/image-20.png)
![삭제 실패 시 전체 삭제](docs/images/image-21.png)

### CloudWatch Logs 권한 오류
```
... not authorized to perform CreateLogGroup with Tags.
An additional permission "logs:TagResource" is required.
```
**해결:** `logs:TagResource` 권한이 포함된 커스텀 정책 추가

![CloudWatch Logs 권한 오류](docs/images/image-22.png)
![권한 추가](docs/images/image-23.png)
![권한 추가 상세](docs/images/image-24.png)
![정책 생성](docs/images/image-25.png)
![정책 생성 완료](docs/images/image-29.png)
![추가 설정 1](docs/images/image-30.png)
![추가 설정 2](docs/images/image-31.png)

### Log Group 중복 오류
```
Resource of type 'AWS::Logs::LogGroup' ... already exists.
```
**해결:** 기존 Log Group 삭제 후 재실행
```bash
aws logs delete-log-group --log-group-name /aws/lambda/<FUNCTION_NAME>
```

![Log Group 중복](docs/images/image-32.png)
![완료 화면](docs/images/image-33.png)

---

## AWS CLI 명령어 모음

```bash
# ── Lambda ────────────────────────────────────────────────────────────
# 함수 목록 조회
aws lambda list-functions --region ap-northeast-2

# 함수 호출
aws lambda invoke \
  --function-name <FUNCTION_NAME> \
  --payload '{"queryStringParameters":{"name":"Test"}}' \
  --cli-binary-format raw-in-base64-out \
  output.json && cat output.json

# 함수 삭제
aws lambda delete-function --function-name <FUNCTION_NAME>

# ── API Gateway ────────────────────────────────────────────────────────
# REST API 목록 조회
aws apigateway get-rest-apis

# ── CloudFormation ─────────────────────────────────────────────────────
# 스택 목록 조회
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# 스택 삭제
aws cloudformation delete-stack --stack-name <STACK_NAME>

# ── S3 ─────────────────────────────────────────────────────────────────
# 버킷 생성
aws s3 mb s3://<BUCKET_NAME> --region ap-northeast-2

# 버킷/객체 목록 조회
aws s3 ls
aws s3 ls s3://<BUCKET_NAME>/

# ── CloudWatch Logs ────────────────────────────────────────────────────
# 로그 그룹 목록
aws logs describe-log-groups

# 로그 스트림 목록
aws logs describe-log-streams --log-group-name /aws/lambda/<FUNCTION_NAME>

# 로그 이벤트 조회
aws logs get-log-events \
  --log-group-name /aws/lambda/<FUNCTION_NAME> \
  --log-stream-name <LOG_STREAM_NAME>
```

![S3 버킷 생성](docs/images/image-36.png)
![CloudWatch Logs 조회](docs/images/image-35.png)

---

## Well-Architected 참고

- AWS 공식 아키텍처 사례: https://aws.amazon.com/ko/architecture

![Well-Architected 소개](docs/images/image-37.png)
![Well-Architected 참고](docs/images/image-38.png)

---

## 후원 안내

이 프로젝트는 **무료 교육 자료**로 운영됩니다.  
AWS 서버리스 학습에 도움이 되었다면 후원을 통해 지속적인 콘텐츠 제작을 응원해 주세요! 🙏

### 💖 후원이 필요한 이유

- ✅ 모든 분께 무료로 콘텐츠 제공 유지
- ✅ 신규 콘텐츠 제작: 더 많은 언어, CI/CD 파이프라인, CDK/Terraform IaC
- ✅ 한국어/영어 동시 문서 업데이트
- ✅ 핸즈온 워크숍 및 실습 자료 확대

### 🙏 후원 방법

| 플랫폼 | 링크 |
|---|---|
| **GitHub Sponsors** | [![Sponsor on GitHub](https://img.shields.io/badge/Sponsor-GitHub-ea4aaa?logo=github)](https://github.com/sponsors/edumgt) |
| **Buy Me a Coffee** | [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/edumgt) |

### 🌟 후원 혜택

| 단계 | 월 금액 | 혜택 |
|---|---|---|
| ☕ 커피 한 잔 | $5 | 서포터 뱃지, 감사 인사 |
| 🚀 부스터 | $20 | 신규 튜토리얼 얼리 액세스, README 이름 등록 |
| 🏢 기업 스폰서 | $100+ | README 로고 등록, 이슈 우선 지원 |

---

## 📚 참고 자료

- [AWS Lambda 개발자 가이드](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [Amazon API Gateway 개발자 가이드](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html)
- [Serverless Framework 문서](https://www.serverless.com/framework/docs/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Fork 추천 GitHub](https://github.com/Carlosrincong/AWS-Solutions-Architect-Associate)

---

## 📄 라이선스

[MIT](LICENSE) © edumgt

> 영문 버전: [README.md](README.md)
