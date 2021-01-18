use std::error::Error;

use lambda_runtime::{error::HandlerError, lambda, Context};
use log::{self}; //, error};
use serde_derive::{Deserialize, Serialize};
use std::collections::HashMap;
// use serde_json::Result;
// use simple_error::bail;
use simple_logger;

#[derive(Deserialize)]
struct CustomEvent {
    // #[serde(rename = "subscriptionId")]
    #[serde(rename = "pathParameters")]
    path_parameters: HashMap<String, String>,
}

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

#[derive(Serialize)]
struct DataOutput {
    message: String,
}

fn main() -> Result<(), Box<dyn Error>> {
    simple_logger::init_with_level(log::Level::Debug)?;
    lambda!(my_handler);

    Ok(())
}

fn my_handler(e: CustomEvent, _c: Context) -> Result<CustomOutput, HandlerError> {
    // if e.subscription_id == "" {
    //     error!("Empty first name in request {}", c.aws_request_id);
    //     bail!("Empty first name");
    // }
    let data = DataOutput {
        message: format!(
            "Hello, {}!",
            e.path_parameters.get("subscriptionId").expect("UNDEF")
        ),
    };
    Ok(CustomOutput::new(serde_json::to_string(&data)?))
}
