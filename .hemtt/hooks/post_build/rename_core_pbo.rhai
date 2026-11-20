// Release signing still needs the original filename until the archive phase.
if HEMTT.is_build() {
    let addons = HEMTT_OUT.join("addons");
    if !addons.join("gait_gait.pbo").move(addons.join("gait.pbo")) {
        fatal("Could not rename the GAIT PBO to gait.pbo");
    }
}
