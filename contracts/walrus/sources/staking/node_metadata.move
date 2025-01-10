// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Metadata that describes a Storage Node. Attached to the `StakingPool`
module walrus::node_metadata;

use std::string::String;
use sui::vec_map::{Self, VecMap};

/// Standard metadata for a Validator. Created during the node registration.
public struct NodeMetadata has copy, drop, store {
    image_url: String,
    project_url: String,
    description: String,
    extra_fields: VecMap<String, String>,
}

/// Create a new `NodeMetadata` instance
public fun new(image_url: String, project_url: String, description: String): NodeMetadata {
    NodeMetadata {
        image_url,
        project_url,
        description,
        extra_fields: vec_map::empty(),
    }
}

/// Set the image URL of the Validator.
public fun set_image_url(metadata: &mut NodeMetadata, image_url: String) {
    metadata.image_url = image_url;
}

/// Set the project URL of the Validator.
public fun set_project_url(metadata: &mut NodeMetadata, project_url: String) {
    metadata.project_url = project_url;
}

/// Set the description of the Validator.
public fun set_description(metadata: &mut NodeMetadata, description: String) {
    metadata.description = description;
}

/// Set an extra field of the Validator.
public fun set_extra_fields(metadata: &mut NodeMetadata, extra_fields: VecMap<String, String>) {
    metadata.extra_fields = extra_fields;
}

// === Accessors ===

/// Returns the image URL of the Validator.
public fun image_url(metadata: &NodeMetadata): String { metadata.image_url }

/// Returns the project URL of the Validator.
public fun project_url(metadata: &NodeMetadata): String { metadata.project_url }

/// Returns the description of the Validator.
public fun description(metadata: &NodeMetadata): String { metadata.description }

/// Returns the extra fields of the Validator.
public fun extra_fields(metadata: &NodeMetadata): &VecMap<String, String> {
    &metadata.extra_fields
}

/// Create a default empty `NodeMetadata` instance.
public(package) fun default(): NodeMetadata {
    NodeMetadata {
        image_url: b"".to_string(),
        project_url: b"".to_string(),
        description: b"".to_string(),
        extra_fields: vec_map::empty(),
    }
}

#[test]
fun test_validator_metadata() {
    use std::unit_test::assert_eq;

    let mut metadata = new(
        b"image_url".to_string(),
        b"project_url".to_string(),
        b"description".to_string(),
    );

    assert_eq!(metadata.image_url(), b"image_url".to_string());
    assert_eq!(metadata.project_url(), b"project_url".to_string());
    assert_eq!(metadata.description(), b"description".to_string());
    assert!(metadata.extra_fields().is_empty());

    metadata.set_image_url(b"new_image_url".to_string());
    metadata.set_project_url(b"new_project_url".to_string());
    metadata.set_description(b"new_description".to_string());

    assert_eq!(metadata.image_url(), b"new_image_url".to_string());
    assert_eq!(metadata.project_url(), b"new_project_url".to_string());
    assert_eq!(metadata.description(), b"new_description".to_string());
}
