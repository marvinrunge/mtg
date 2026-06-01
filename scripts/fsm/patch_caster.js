const fs = require('fs');
let content = fs.readFileSync('scripts/PlayerCaster.gd', 'utf8');

content = content.replace(/controller\.play_anim\("([^"]+)"\)/g, `controller.play_anim("$1")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")`);

fs.writeFileSync('scripts/PlayerCaster.gd', content, 'utf8');
console.log("PlayerCaster patched.");
