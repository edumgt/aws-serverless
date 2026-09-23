# S3 CRUD REST API: curl 명령 모음

이 API는 `public-crud-100kb-086015456585` 버킷을 사용합니다. AWS CLI나 AWS 계정 설정은 필요하지 않습니다. 아래 명령은 Ubuntu의 Bash에서 실행하며, 먼저 같은 셸에서 기본 URL을 지정하세요.

```bash
API='https://ukj78wqnd9.execute-api.ap-northeast-2.amazonaws.com/prod/objects'
```

URL을 복사할 때 Markdown 링크 형식인 `[주소](주소)` 대신 위의 실제 주소만 사용하세요. 예시의 `images/image.png`는 S3 객체 키입니다.

## Create: 파일 업로드 (POST)

로컬 `./image.png`를 `images/image.png`라는 키로 업로드합니다.

```bash
{
  printf '{"key":"images/image.png","content_base64":"'
  base64 -w 0 ./image.png
  printf '","content_type":"image/png"}'
} | curl -sS -X POST "$API" \
  -H 'Content-Type: application/json' \
  --data-binary @-
```

파일 내용을 표준 입력으로 전달하므로 큰 Base64 문자열을 셸 명령 인자로 넘기지 않습니다.

## Read: 객체 목록 조회 (GET)

```bash
curl -sS --get --data-urlencode 'prefix=images/' "$API"
```

응답의 `objects`에 키와 크기가 표시됩니다. `next_token`이 있으면 다음 페이지를 조회할 때 `--data-urlencode 'continuation_token=토큰값'`을 추가하세요.

## Read: 파일 다운로드 (GET)

이 API는 파일을 직접 반환하지 않고 JSON의 `content_base64`에 담아 반환합니다. 아래 명령은 이를 디코딩해 로컬 파일로 저장합니다.

```bash
set -o pipefail
curl --fail-with-body -sS "$API/images/image.png" |
  python3 -c 'import base64, json, sys; sys.stdout.buffer.write(base64.b64decode(json.load(sys.stdin)["content_base64"]))' \
  > ./downloaded-image.png
```

## Update: 파일 덮어쓰기 (PUT)

로컬 `./new-image.png`의 내용으로 기존 `images/image.png` 객체를 갱신합니다.

```bash
{
  printf '{"content_base64":"'
  base64 -w 0 ./new-image.png
  printf '","content_type":"image/png"}'
} | curl -sS -X PUT "$API/images/image.png" \
  -H 'Content-Type: application/json' \
  --data-binary @-
```

## Delete: 객체 삭제 (DELETE)

```bash
curl -sS -X DELETE "$API/images/image.png"
```

## CORS 확인 (OPTIONS)

```bash
curl -i -X OPTIONS "$API" \
  -H 'Origin: http://localhost:3000' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type'
```

객체 키에 공백이나 `#` 같은 특수 문자가 있으면 URL 경로에서 인코딩해야 합니다.
