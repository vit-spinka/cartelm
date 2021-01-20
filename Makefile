.PHONY: all rust

all: rust terraform

terraform:
	cd terraform && terraform apply

rust:
	cd rust && cargo build --release --target x86_64-unknown-linux-musl
	cd rust && cp ./target/x86_64-unknown-linux-musl/release/list_all ./bootstrap && zip list_all.zip bootstrap && rm bootstrap
	cd rust && cp ./target/x86_64-unknown-linux-musl/release/update ./bootstrap && zip update.zip bootstrap && rm bootstrap
	cd rust && cp ./target/x86_64-unknown-linux-musl/release/get ./bootstrap && zip get.zip bootstrap && rm bootstrap
	cd rust && cp ./target/x86_64-unknown-linux-musl/release/delete ./bootstrap && zip delete.zip bootstrap && rm bootstrap
	cd rust && cp ./target/x86_64-unknown-linux-musl/release/create ./bootstrap && zip create.zip bootstrap && rm bootstrap	
	cd rust && cp ./target/x86_64-unknown-linux-musl/release/scrape_dilbert ./bootstrap && zip scrape_dilbert.zip bootstrap && rm bootstrap