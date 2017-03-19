with open('public-keys') as f:
	filename = None
	for line in f:
		line = line.strip()
		if len(line) > 1:
			if line[0] == "#":
				filename = line[1:]
			else:
				text_file = open("ssh-public-keys/"+filename+".pub", "w")
				text_file.write(line)
				text_file.close()
