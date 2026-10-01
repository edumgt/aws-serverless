# AWS SAM init 템플릿 실습

이 디렉터리는 `sam init`에서 선택할 수 있는 대표적인 관리형 템플릿을 사용 사례별로 정리합니다. 각 문서는 템플릿 생성부터 빌드, 로컬 확인, 배포 및 정리까지의 기본 흐름을 설명합니다.

## 시작하기

필요한 도구:

- AWS SAM CLI와 AWS CLI
- AWS 자격 증명 및 배포 권한
- 로컬 실행 시 Docker

템플릿 카탈로그는 SAM CLI 버전에 따라 바뀔 수 있습니다. 설치된 버전에서 `sam init`을 실행해 대화형 선택지를 확인하거나, 아래 문서의 `sam init` 명령으로 예제를 생성하세요. 명령의 `--name` 값은 원하는 애플리케이션 이름으로 바꿔도 됩니다.

| 번호 | 템플릿 사용 사례 | 문서 |
| --- | --- | --- |
| 1 | 데이터 처리 (S3, SNS, SQS) | [sam1.md](sam1.md) |
| 2 | Durable Functions | [sam2.md](sam2.md) |
| 3 | DynamoDB | [sam3.md](sam3.md) |
| 4 | Full Stack | [sam4.md](sam4.md) |
| 5 | GraphQL API | [sam5.md](sam5.md) |
| 6 | Hello World Durable Function | [sam6.md](sam6.md) |
| 7 | Hello World | [sam7.md](sam7.md) |
| 8 | Powertools for AWS Lambda | [sam8.md](sam8.md) |
| 9 | EventBridge 이벤트 관리 | [sam9.md](sam9.md) |
| 10 | EFS 연결 Lambda | [sam10.md](sam10.md) |
| 11 | Lambda 응답 스트리밍 | [sam11.md](sam11.md) |
| 12 | 머신러닝 추론 API | [sam12.md](sam12.md) |
| 13 | Step Functions 워크플로 | [sam13.md](sam13.md) |
| 14 | Step Functions와 Connectors | [sam14.md](sam14.md) |
| 15 | 예약 작업 | [sam15.md](sam15.md) |
| 16 | 서버리스 웹 API | [sam16.md](sam16.md) |
| 17 | Serverless Connector | [sam17.md](sam17.md) |
| 18 | 독립 실행 Lambda 함수 | [sam18.md](sam18.md) |

## 공통 작업 흐름

각 예제에서 `sam init` 명령을 실행하면 현재 디렉터리에 지정한 이름의 애플리케이션 폴더가 생성됩니다.

```bash
cd <애플리케이션-폴더>
sam validate
sam build
sam local invoke
sam deploy --guided
```

HTTP API는 `sam local start-api`로 로컬 서버를 실행하고, 출력된 URL을 `curl`로 호출할 수 있습니다. `sam local` 명령은 Docker가 필요할 수 있습니다. AWS에 배포할 때는 계정에 맞는 리전과 CloudFormation, Lambda 및 템플릿에 선언된 리소스 권한을 사용하세요. 사용을 마친 스택은 실제 스택 이름으로 `sam delete --stack-name <스택-이름>`을 실행해 삭제합니다.

> **주의:** 이벤트 소스, API, EFS, 컨테이너 이미지, Step Functions 등은 AWS 리소스를 생성하거나 요금을 발생시킬 수 있습니다. 배포 전 템플릿을 확인하고, 실습이 끝나면 스택과 생성된 데이터 리소스를 정리하세요.
