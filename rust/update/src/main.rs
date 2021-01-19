use std::error::Error;

use lambda_runtime::{error::HandlerError, lambda, Context};
use rusoto_core::Region;
use rusoto_dynamodb::{AttributeValue, DynamoDb, DynamoDbClient, PutItemInput};
use serde_derive::{Deserialize, Serialize};
use simple_logger::SimpleLogger;
use std::collections::HashMap;
use std::env;

#[derive(Deserialize)]
struct ItemData {
    cartoon: String,
    email: String,
}

#[derive(Deserialize)]
struct CustomEvent {
    #[serde(rename = "pathParameters")]
    path_parameters: HashMap<String, String>,
    body: String,
}

#[derive(Serialize, Clone)]
struct CustomOutput {
    #[serde(rename = "isBase64Encoded")]
    is_base64_encoded: bool,
    #[serde(rename = "statusCode")]
    status_code: u16,
}

impl CustomOutput {
    fn new() -> Self {
        CustomOutput {
            is_base64_encoded: false,
            status_code: 204,
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
    let mut item: HashMap<String, AttributeValue> = HashMap::new();
    let itemdata: ItemData = serde_json::from_str(&e.body)?;
    let subscription_id = e
        .path_parameters
        .get("subscriptionId")
        .expect("subscriptionId not present")
        .to_string();

    item.insert(
        "subscriptionId".to_string(),
        AttributeValue {
            s: Some(subscription_id),
            ..Default::default()
        },
    );
    item.insert(
        "email".to_string(),
        AttributeValue {
            s: Some(itemdata.email),
            ..Default::default()
        },
    );
    item.insert(
        "cartoon".to_string(),
        AttributeValue {
            s: Some(itemdata.cartoon),
            ..Default::default()
        },
    );

    let dynanmodb_request = PutItemInput {
        item: item,
        table_name: table_name,
        ..Default::default()
    };

    let dynamodb_result = dynamodb_client.put_item(dynanmodb_request);
    let put_item_output = dynamodb_result.sync();

    match put_item_output {
        Ok(_) => Ok(CustomOutput::new()),
        Err(error) => Err(HandlerError::from(format!("{:?}", error).as_str())),
    }
}
