use std::error::Error;

// use lambda_runtime::{error::HandlerError, lambda, Context};
use log::{self}; //, error};
use serde_derive::{Deserialize, Serialize};
use std::collections::HashMap;
// use serde_json::Result;
// use simple_error::bail;
use futures::executor;
use rusoto_core::Region;
use rusoto_dynamodb::{AttributeValue, DynamoDb, DynamoDbClient, GetItemInput};
use simple_logger;
use std::env;
// use tokio::runtime::Runtime;

#[derive(Serialize, Debug)]
struct Item {
    #[serde(rename = "subscriptionId")]
    subscription_id: String,
    cartoon: String,
    email: String,
}

#[derive(Deserialize)]
struct CustomEvent {
    // #[serde(rename = "subscriptionId")]
    #[serde(rename = "pathParameters")]
    path_parameters: HashMap<String, String>,
}

#[derive(Serialize, Clone, Debug)]
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

type DataOutput = Option<Item>;

fn main() {
    simple_logger::init_with_level(log::Level::Debug).unwrap();
    // let runtime = Runtime::new().expect("Failed to create Tokio runtime");

    // if e.subscription_id == "" {
    //     error!("Empty first name in request {}", c.aws_request_id);
    //     bail!("Empty first name");
    // }
    // let region = env::var("AWS_REGION");
    let table_name = env::var("DYNAMODB_TABLE").expect("DYNAMODB_TABLE not set");
    let dynamodb_client = DynamoDbClient::new(Region::default());
    let mut key_pair: HashMap<String, AttributeValue> = HashMap::new();
    key_pair.insert(
        "subscriptionId".to_string(),
        AttributeValue {
            s: Some("1-2-3".to_string()),
            ..Default::default()
        },
    );
    // ]
    // .into_iter()
    // .collect();

    let dynanmodb_request = GetItemInput {
        key: key_pair,
        table_name: table_name,
        ..Default::default()
    };

    let dynamodb_result = dynamodb_client.get_item(dynanmodb_request);
    // let get_item_output = executor::block_on(dynamodb_result).ok();
    let get_item_output = dynamodb_result.sync().unwrap();

    let data = //get_item_output.map(|output| {
        get_item_output.item.map(|item| Item {
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
    ; //});

    // let data = Some(Item {
    //     subscription_id: "123".to_string(),
    //     cartoon: "X".to_string(),
    //     email: "A".to_string(),
    //     // message: format!(
    //     //     "Hello, {}!",
    //     //     e.path_parameters.get("subscriptionId").expect("UNDEF")
    //     // ),
    // });
    println!("{:?}", serde_json::to_string(&data));
    // Ok(CustomOutput::new(serde_json::to_string(&data)?))
}
