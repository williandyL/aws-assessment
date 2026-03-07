#!/bin/bash


# CLIENT_ID="YOUR_COGNITO_CLIENT_ID"
# USERNAME="testuser@example.com"
# PASSWORD="YourPassword123!"


# API_R1="https://r1-api.execute-api.us-east-1.amazonaws.com/prod"
# API_R2="https://r2-api.execute-api.eu-west-1.amazonaws.com/prod"

echo $COGNITO_REGION
echo $CLIENT_ID
echo $USERNAME

ID_TOKEN=$(aws cognito-idp initiate-auth \
    --region $COGNITO_REGION \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id $CLIENT_ID \
    --auth-parameters "USERNAME=$USERNAME,PASSWORD=$PASSWORD" \
    --query 'AuthenticationResult.IdToken' \
    --output text)

if [ "$ID_TOKEN" == "None" ] || [ -z "$ID_TOKEN" ]; then
    echo "Authentication failed!"
    exit 1
fi
echo "JWT Retrieved successfully."

call_endpoint() {
    local url=$1
    local label=$2
    local expected=$3
    
    echo -e "\n--- Testing $label ---"
    
    start_time=$(date +%s%3N)
    response=$(curl -s -w "\n%{http_code}\n%{time_total}" \
        -H "Authorization: Bearer $ID_TOKEN" \
        "$url")
    end_time=$(date +%s%3N)
    
    body=$(echo "$response" | sed -n '1p')
    status=$(echo "$response" | sed -n '2p')
    latency=$(echo "$response" | sed -n '3p')
    
    ms_latency=$(echo "$latency * 1000" | bc -l | xargs printf "%.2f")

    echo "Status: $status"
    echo "Latency: ${ms_latency}ms"
    echo "Response: $body"

    if [[ "$body" == *"$expected"* ]]; then
        echo "Match:  (Found $expected)"
    else
        echo "Match:  (Expected $expected)"
    fi
}

call_endpoint "$API_R1/greet" "Region 1 Greet" "us-east-1"

# 2. Test Region 2 Greet
call_endpoint "$API_R2/greet" "Region 2 Greet" "eu-west-1"

# 3. Test Region 1 Dispatch
call_endpoint "$API_R1/dispatch" "Region 1 Dispatch" "us-east-1"

# 4. Test Region 2 Dispatch
call_endpoint "$API_R2/dispatch" "Region 2 Dispatch" "eu-west-1"

echo -e "Validation Complete."