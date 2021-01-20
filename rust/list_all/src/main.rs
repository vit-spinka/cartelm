use std::error::Error;

use lambda_runtime::{error::HandlerError, lambda, Context};
use rusoto_core::Region;
use rusoto_dynamodb::{DynamoDb, DynamoDbClient, ScanInput};
use serde_derive::{Deserialize, Serialize};
use simple_logger::SimpleLogger;
use std::env;

#[derive(Serialize)]
struct Item {
    #[serde(rename = "subscriptionId")]
    subscription_id: String,
    cartoon: String,
    email: String,
}

#[derive(Deserialize)]
struct CustomEvent {}

#[derive(Serialize, Clone)]
struct CustomOutput {
    #[serde(rename = "isBase64Encoded")]
    is_base64_encoded: bool,
    #[serde(rename = "statusCode")]
    status_code: u16,
    body: String,
}

impl CustomOutput {
    fn new(body: String) -> Self {
        CustomOutput {
            is_base64_encoded: false,
            status_code: 200,
            body,
        }
    }
}

type DataOutput = Vec<Item>;

fn main() -> Result<(), Box<dyn Error>> {
    SimpleLogger::new().init()?;
    lambda!(my_handler);

    Ok(())
}

fn my_handler(_e: CustomEvent, _c: Context) -> Result<CustomOutput, HandlerError> {
    let table_name = env::var("DYNAMODB_TABLE").expect("DYNAMODB_TABLE not set");
    let dynamodb_client = DynamoDbClient::new(Region::default());

    let dynanmodb_request = ScanInput {
        table_name,
        ..Default::default()
    };

    let dynamodb_result = dynamodb_client.scan(dynanmodb_request);
    let get_item_output = dynamodb_result.sync();

    match get_item_output {
        Ok(get_item_output) => {
            let data: DataOutput = get_item_output
                .items
                .unwrap()
                .into_iter()
                .map(|item| Item {
                    subscription_id: item
                        .get("subscriptionId")
                        .unwrap()
                        .s
                        .as_ref()
                        .unwrap()
                        .clone(),
                    cartoon: item.get("cartoon").unwrap().s.as_ref().unwrap().clone(),
                    email: item.get("email").unwrap().s.as_ref().unwrap().clone(),
                })
                .collect();
            Ok(CustomOutput::new(serde_json::to_string(&data)?))
        }
        Err(error) => Err(HandlerError::from(format!("{:?}", error).as_str())),
    }
}
