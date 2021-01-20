use lettre::SendableEmail;
use lettre_email::EmailBuilder;

use scraper::{Html, Selector};

use rusoto_core::Region;
use rusoto_ses::{Ses, SesClient};

fn main() {
    let (image_url, date_encoded, _date_human) = scrape_website("https://dilbert.com");

    let image_data = reqwest::blocking::get(&image_url).unwrap().bytes().unwrap();

    println!(
        "{}#{}#{}",
        &date_encoded[0..4],
        &date_encoded[5..7],
        &date_encoded[8..10]
    );

    let (y, m, d) = (
        &date_encoded[0..4].parse::<u16>().unwrap(),
        &date_encoded[5..7].parse::<u16>().unwrap(),
        &date_encoded[8..10].parse::<u16>().unwrap(),
    );

    send_email(
        "vit.spinka@gmail.com".to_string(),
        "vit.spinka@gmail.com".to_string(),
        format!("Dilbert for {}.{}.{}", d, m, y),
        &format!("{}.gif", date_encoded),
        &image_data.to_vec(),
    );
}

fn send_email(
    from: String,
    to: String,
    subject: String,
    attachment_filename: &str,
    attachment: &[u8],
) {
    let email: SendableEmail = EmailBuilder::new()
        .to(to)
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
        Ok(p) => println!("{:?}", p),
        Err(err) => println!("{:?}", err),
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
