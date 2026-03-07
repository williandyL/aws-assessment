import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";

const ddbClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(ddbClient);
const snsClient = new SNSClient({});

export const handler = async (event) => {
    const TABLE_NAME = "GreetingLogs"; 
    const TOPIC_ARN = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic";
    const USER_EMAIL = "williandy.str@gmail.com";
    const REPO_URL = "https://github.com/williandyL/aws-assessment";
    const REGION = process.env.AWS_REGION || "us-east-1";

    try {
        const dbParams = {
            TableName: TABLE_NAME,
            Item: {
                id: Date.now().toString(),
                timestamp: new Date().toISOString(),
                message: "Greeting processed",
                email: USER_EMAIL
            }
        };

        await docClient.send(new PutCommand(dbParams));
        console.log("DynamoDB record created successfully.");

        const snsPayload = {
            email: USER_EMAIL,
            source: "Lambda",
            region: REGION,
            repo: REPO_URL
        };

        const snsParams = {
            TopicArn: TOPIC_ARN,
            Message: JSON.stringify(snsPayload)
        };

        await snsClient.send(new PublishCommand(snsParams));
        console.log("SNS verification message published.");

        return {
            statusCode: 200,
            body: JSON.stringify({ message: "Success", region: REGION }),
        };

    } catch (error) {
        console.error("Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Internal Server Error", details: error.message }),
        };
    }
};