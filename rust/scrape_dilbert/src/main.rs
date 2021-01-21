use lettre::SendableEmail;
use lettre_email::EmailBuilder;

use scraper::{Html, Selector};

use rusoto_core::Region;
use rusoto_dynamodb::{AttributeValue, DynamoDb, DynamoDbClient, ScanInput};
use rusoto_ses::{Ses, SesClient};
use std::collections::HashMap;
use std::env;

fn main() {
    let (image_url, date_encoded, _date_human) = scrape_website("https://dilbert.com");

    let image_data = reqwest::blocking::get(&image_url).unwrap().bytes().unwrap();

    let (y, m, d) = (
        &date_encoded[0..4].parse::<u16>().unwrap(),
        &date_encoded[5..7].parse::<u16>().unwrap(),
        &date_encoded[8..10].parse::<u16>().unwrap(),
    );

    for to in scan_table("dilbert") {
        send_email(
            "vit.spinka@gmail.com".to_string(),
            to,
            format!("Dilbert for {}.{}.{}", d, m, y),
            &format!("{}.gif", date_encoded),
            &image_data.to_vec(),
        );
    }
}

fn send_email(
    from: String,
    to: String,
    subject: String,
    attachment_filename: &str,
    attachment: &[u8],
) {
    let email: SendableEmail = EmailBuilder::new()
        .to(to.clone())
        .from(from)
        .subject(subject)
        .attachment(attachment, attachment_filename, &mime::IMAGE_GIF)
        .unwrap()
        .build()
        .unwrap()
        .into();

    let email_as_string = email.message_to_string().unwrap();

    // println!("{}", email_as_string);

    let ses_client = SesClient::new(Region::UsEast1);

    let raw_message = rusoto_ses::RawMessage {
        data: bytes::Bytes::from(base64::encode(email_as_string)),
    };
    let request = rusoto_ses::SendRawEmailRequest {
        configuration_set_name: None,
        destinations: None,
        from_arn: None,
        raw_message,
        return_path_arn: None,
        source: None,
        source_arn: None,
        tags: None,
    };

    let rt = ses_client.send_raw_email(request).sync();

    match rt {
        Ok(p) => println!("{} {:?}", &to, p),
        Err(err) => println!("{} {:?}", &to, err),
    };
}

fn scrape_website(url: &str) -> (String, String, String) {
    let resp = reqwest::blocking::get(url).unwrap();
    assert!(resp.status().is_success());
    let body = resp.text().unwrap();
    // parses string of HTML as a document
    let fragment = Html::parse_document(&body);
    // parses based on a CSS selector
    let stories = Selector::parse(".comic-item-container").unwrap();
    // iterate over elements matching our selector
    // just get first one (=the most recent comics)
    let input = fragment.select(&stories).next().unwrap();

    (
        input.value().attr("data-image").unwrap().to_string(),
        input.value().attr("data-id").unwrap().to_string(),
        input.value().attr("data-date").unwrap().to_string(),
    )
}

fn scan_table(cartoon: &str) -> Vec<String> {
    let table_name = env::var("DYNAMODB_TABLE").expect("DYNAMODB_TABLE not set");
    let dynamodb_client = DynamoDbClient::new(Region::default());

    let filter_expression = "cartoon = :c";
    let mut expression_attribute_values: HashMap<String, AttributeValue> = HashMap::new();

    expression_attribute_values.insert(
        ":c".to_string(),
        AttributeValue {
            s: Some(cartoon.to_string()),
            ..Default::default()
        },
    );

    let dynanmodb_request = ScanInput {
        expression_attribute_values: Some(expression_attribute_values),
        filter_expression: Some(filter_expression.to_string()),
        table_name,
        ..Default::default()
    };

    let dynamodb_result = dynamodb_client.scan(dynanmodb_request);
    let scan_output = dynamodb_result.sync();

    if let Ok(scan_items) = scan_output {
        let items = scan_items.items.unwrap();
        items
            .iter()
            .map(|item| item.get("email").unwrap().s.as_ref().unwrap().clone())
            .collect::<Vec<String>>()
    } else {
        vec![]
    }
}
