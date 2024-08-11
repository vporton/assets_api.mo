module {
    public type BatchId = Nat;
    public type ChunkId = Nat;
    public type Key = Text;
    public type Time = Int;

    public type CreateAssetArguments = {
        key: Key;
        content_type: Text;
        max_age: ?Nat64;
        headers: ?[HeaderField];
        enable_aliasing: ?Bool;
        allow_raw_access: ?Bool;
    };

    // Add or change content for an asset, by content encoding
    public type SetAssetContentArguments = {
        key: Key;
        content_encoding: Text;
        chunk_ids: [ChunkId];
        sha256: ?Blob;
    };

    // Remove content for an asset, by content encoding
    public type UnsetAssetContentArguments = {
        key: Key;
        content_encoding: Text;
    };

    // Delete an asset
    public type DeleteAssetArguments = {
        key: Key;
    };

    // Reset everything
    public type ClearArguments = {};

    public type BatchOperationKind = {
        #CreateAsset: CreateAssetArguments;
        #SetAssetContent: SetAssetContentArguments;

        #SetAssetProperties: SetAssetPropertiesArguments;

        #UnsetAssetContent: UnsetAssetContentArguments;
        #DeleteAsset: DeleteAssetArguments;

        #Clear: ClearArguments;
    };

    public type CommitBatchArguments = {
        batch_id: BatchId;
        operations: [BatchOperationKind];
    };

    public type CommitProposedBatchArguments = {
        batch_id: BatchId;
        evidence: Blob;
    };

    public type ComputeEvidenceArguments = {
        batch_id: BatchId;
        max_iterations: ?Nat16;
    };

    public type DeleteBatchArguments = {
        batch_id: BatchId;
    };

    public type HeaderField = (Text, Text);

    public type HttpRequest = {
        method: Text;
        url: Text;
        headers: [HeaderField];
        body: Blob;
        certificate_version: ?Nat16;
    };

    public type HttpResponse = {
        status_code: Nat16;
        headers: [HeaderField];
        body: Blob;
        streaming_strategy: ?StreamingStrategy;
    };

    public type StreamingCallbackHttpResponse = {
        body: Blob;
        token: ?StreamingCallbackToken;
    };

    public type StreamingCallbackToken = {
        key: Key;
        content_encoding: Text;
        index: Nat;
        sha256: ?Blob;
    };

    public type StreamingStrategy = {
        #Callback: {
            callback: query (StreamingCallbackToken) -> async (?StreamingCallbackHttpResponse);
            token: StreamingCallbackToken;
        };
    };

    public type SetAssetPropertiesArguments = {
        key: Key;
        max_age: ??Nat64;
        headers: ??[HeaderField];
        allow_raw_access: ??Bool;
        is_aliased: ??Bool;
    };

    public type ConfigurationResponse = {
        max_batches: ?Nat64;
        max_chunks: ?Nat64;
        max_bytes: ?Nat64;
    };

    public type ConfigureArguments = {
        max_batches: ??Nat64;
        max_chunks: ??Nat64;
        max_bytes: ??Nat64;
    };

    public type Permission = {
        #Commit;
        #ManagePermissions;
        #Prepare;
    };

    public type GrantPermission = {
        to_principal: Principal;
        permission: Permission;
    };
    public type RevokePermission = {
        of_principal: Principal;
        permission: Permission;
    };
    public type ListPermitted = { permission: Permission };

    public type ValidationResult = { #Ok : Text; #Err : Text };

    public type AssetCanisterArgs = {
        #Init: InitArgs;
        #Upgrade: UpgradeArgs;
    };

    public type InitArgs = {};

    public type UpgradeArgs = {
        set_permissions: ?SetPermissions;
    };

    /// Sets the list of principals granted each permission.
    public type SetPermissions = {
        prepare: [Principal];
        commit: [Principal];
        manage_permissions: [Principal];
    };

    public type AssetCanister = actor {
        api_version: query () -> async (Nat16);

        get: query ({
            key: Key;
            accept_encodings: [Text];
        }) -> async ({
            content: Blob; // may be the entirety of the content, or just chunk index 0
            content_type: Text;
            content_encoding: Text;
            sha256: ?Blob; // sha256 of entire asset encoding, calculated by dfx and passed in SetAssetContentArguments
            total_length: Nat; // all chunks except last have size == content.size()
        });

        // if get() returned chunks > 1, call this to retrieve them.
        // chunks may or may not be split up at the same boundaries as presented to create_chunk().
        get_chunk: query ({
            key: Key;
            content_encoding: Text;
            index: Nat;
            sha256: ?Blob;  // sha256 of entire asset encoding, calculated by dfx and passed in SetAssetContentArguments
        }) -> async ({ content: Blob });

        list : query ({}) -> async ([{
            key: Key;
            content_type: Text;
            encodings: [{
                content_encoding: Text;
                sha256: ?Blob; // sha256 of entire asset encoding, calculated by dfx and passed in SetAssetContentArguments
                length: Nat; // Size of this encoding's Blob. Calculated when uploading assets.
                modified: Time;
            }];
        }]);

        certified_tree : query ({}) -> async ({
            certificate: Blob;
            tree: Blob;
        });

        create_batch: ({}) -> async ({ batch_id: BatchId });

        create_chunk: ({ batch_id: BatchId; content: Blob }) -> async ({ chunk_id: ChunkId });

        // Perform all operations successfully, or reject
        commit_batch: (CommitBatchArguments) -> async ();

        // Save the batch operations for later commit
        propose_commit_batch: (CommitBatchArguments) -> async ();

        // Given a batch already proposed, perform all operations successfully, or reject
        commit_proposed_batch: (CommitProposedBatchArguments) -> async ();

        // Compute a hash over the CommitBatchArguments.  Call until it returns Some(evidence).
        compute_evidence: (ComputeEvidenceArguments) -> async (?Blob);

        // Delete a batch that has been created, or proposed for commit, but not yet committed
        delete_batch: (DeleteBatchArguments) -> async ();

        create_asset: (CreateAssetArguments) -> async ();
        set_asset_content: (SetAssetContentArguments) -> async ();
        unset_asset_content: (UnsetAssetContentArguments) -> async ();

        delete_asset: (DeleteAssetArguments) -> async ();

        clear: (ClearArguments) -> async ();

        // Single call to create an asset with content for a single content encoding that
        // fits within the message ingress limit.
        store: ({
            key: Key;
            content_type: Text;
            content_encoding: Text;
            content: Blob;
            sha256: ?Blob
        }) -> async ();

        http_request: query (request: HttpRequest) -> async (HttpResponse);
        http_request_streaming_callback: query (token: StreamingCallbackToken) -> async (?StreamingCallbackHttpResponse);

        authorize: (Principal) -> async ();
        deauthorize: (Principal) -> async ();
        list_authorized: () -> async ([Principal]);
        grant_permission: (GrantPermission) -> async ();
        revoke_permission: (RevokePermission) -> async ();
        list_permitted: (ListPermitted) -> async ([Principal]);
        take_ownership: () -> async ();

        get_asset_properties : query (key: Key) -> async ({
            max_age: ?Nat64;
            headers: ?[HeaderField];
            allow_raw_access: ?Bool;
            is_aliased: ?Bool; } );
        set_asset_properties: (SetAssetPropertiesArguments) -> async ();

        get_configuration: () -> async (ConfigurationResponse);
        configure: (ConfigureArguments) -> async ();

        validate_grant_permission: (GrantPermission) -> async (ValidationResult);
        validate_revoke_permission: (RevokePermission) -> async (ValidationResult);
        validate_take_ownership: () -> async (ValidationResult);
        validate_commit_proposed_batch: (CommitProposedBatchArguments) -> async (ValidationResult);
        validate_configure: (ConfigureArguments) -> async (ValidationResult);
    }
}
