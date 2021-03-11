use std::error::Error;

use lambda_runtime::{error::HandlerError, lambda, Context};
use rusoto_core::Region;
use rusoto_dynamodb::{AttributeValue, DeleteItemInput, DynamoDb, DynamoDbClient};
use serde_derive::{Deserialize, Serialize};
use simple_logger::SimpleLogger;
use std::collections::HashMap;
use std::env;

#[derive(Deserialize)]
struct CustomEvent {
    #[serde(rename = "pathParameters")]
    path_parameters: HashMap<String, String>,
}

#[derive(Serialize, Clone)]
struct CustomOutput {
    #[serde(rename = "isBase64Encoded")]
    is_base64_encoded: bool,
    #[serde(rename = "statusCode")]
    status_code: u16,
    headers: HashMap<&'static str, &'static str>,
}

impl CustomOutput {
    fn new() -> Self {
        CustomOutput {
            is_base64_encoded: false,
            status_code: 204,
            headers: vec![("Access-Control-Allow-Origin", "*")]
                .into_iter()
                .collect(),
        }
    }
}

// type DataOutput = Option<Item>;

fn main() -> Result<(), Box<dyn Error>> {
    SimpleLogger::new().init()?;
    lambda!(my_handler);

    Ok(())
}

fn my_handler(e: CustomEvent, _c: Context) -> Result<CustomOutput, HandlerError> {
    let table_name = env::var("DYNAMODB_TABLE").expect("DYNAMODB_TABLE not set");
    let dynamodb_client = DynamoDbClient::new(Region::default());
    let mut key_pair: HashMap<String, AttributeValue> = HashMap::new();
    key_pair.insert(
        "subscriptionId".to_string(),
        AttributeValue {
            s: Some(
                e.path_parameters
                    .get("subscriptionId")
                    .expect("subscriptionId not present")
                    .to_string(),
            ),
            ..Default::default()
        },
    );

    let dynanmodb_request = DeleteItemInput {
        key: key_pair,
        table_name,
        ..Default::default()
    };

    let dynamodb_result = dynamodb_client.delete_item(dynanmodb_request);
    let delete_item_output = dynamodb_result.sync();

    match delete_item_output {
        Ok(_) => Ok(CustomOutput::new()),
        Err(error) => Err(HandlerError::from(format!("{:?}", error).as_str())),
    }
}
