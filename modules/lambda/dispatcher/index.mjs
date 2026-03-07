import { ECSClient, RunTaskCommand } from "@aws-sdk/client-ecs";

const ecsClient = new ECSClient({ region: process.env.AWS_REGION });

export const handler = async (event) => {
    try {
        const params = {
            cluster: "exam",
            taskDefinition: "sns-publisher-task",
            launchType: "FARGATE",
            networkConfiguration: {
                awsvpcConfiguration: {
                    subnets: [process.env.SUBNET],
                    securityGroups: [process.env.SG],
                    assignPublicIp: "ENABLED",
                },
            },
            overrides: {
                containerOverrides: [
                    {
                        name: "publisher-container",
                        environment: [
                            { name: "USER_EMAIL", value: "williandy.str@example.com" },
                            { name: "REPO_URL", value: "https://github.com/williandyL/aws-assessment" }
                        ],
                    },
                ],
            },
        };

        const command = new RunTaskCommand(params);
        const response = await ecsClient.send(command);

        return {
            statusCode: 200,
            body: JSON.stringify({
                message: "ECS Task dispatched successfully",
                taskArn: response.tasks[0].taskArn,
            }),
        };
    } catch (error) {
        console.error(error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message }),
        };
    }
};