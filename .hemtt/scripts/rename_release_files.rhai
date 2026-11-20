let addons = HEMTT_OUT.join("addons");
let built = addons.join("gait_gait.pbo");
if built.is_file() && !built.move(addons.join("gait.pbo")) {
    fatal("Could not rename the GAIT PBO to gait.pbo");
}

for signature in addons.list() {
    let name = signature.file_name();
    if name.starts_with("gait_gait.pbo.") && signature.file_ext() == "bisign" {
        name.replace("gait_gait.pbo.", "gait.pbo.");
        if !signature.move(addons.join(name)) {
            fatal("Could not rename the GAIT signature");
        }
    }
}

let keys = HEMTT_OUT.join("keys");
if keys.is_dir() {
    for key in keys.list() {
        if key.file_ext() == "bikey" && key.file_name() != "GAIT.bikey" {
            if !key.move(keys.join("GAIT.bikey")) {
                fatal("Could not rename the GAIT public key");
            }
        }
    }
}
