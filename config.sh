{
	"ociVersion": "1.0.0",
	"process": {
		"user": {
			"uid": 4826,
			"gid": 4826
		},
	        "args": [
		        "/src/entrypoint.sh",
		        "retroarch",
		        "-v"
		],
		"env": [
			"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
		        "TERM=xterm"
		],
	        "cwd": "/app/retroarch"
	},
	"root": {
		"path": "rootfs"
	},
	"hostname": "retroarch-rafi"
}
