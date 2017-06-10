SHELL=/bin/bash
lxc_image_name=ubuntu:16.04
test_container_name=saltsolo

# Test for required programs to run this make
EXECUTABLES = jq lxc lxd
K := $(foreach exec,$(EXECUTABLES),\
	        $(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))

# Check LXC/LXD prerequisites
check-lxc-prereq:
ifeq (, $(shell which lxd))
	$(error "No LXD in $(PATH), consider installing LXD/LXC packages")
endif


.PHONY: all
all: build

.PHONY: increment
increment:

#Clean all
clean:	clean-test

#Clean Test Environment
clean-test:
	lxc stop $(test_container_name)

test-lxc-prepare: test-lxc-announce check-lxc-prereq test-lxc-wait

test-lxc-setup: check-lxc-prereq 
	@echo "================================"
	@echo "Setting up LXC test environment"
	@lxc info $(test_container_name) 1>/dev/null 2>&1 || \
		lxc launch $(lxc_image_name) $(test_container_name) --ephemeral
	@echo -n "Waiting for environment to have IP ."
	@while [[ ! "$$(lxc list $(test_container_name) --format json | jq -r '.[] .state.network.eth0.addresses[0].address' )" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$$ ]]; do echo -n "."; sleep 1; done
	@echo ""
	@echo "Container up at IP $$(lxc list $(test_container_name) --format json | jq -r '.[] .state.network.eth0.addresses[0].address')"
	@echo "Adding current user key to root for SSH"
	@lxc exec saltsolo -- bash -c "while [ ! -d /root/.ssh ]; do sleep 1; done"  #Added this because there have been race issues where IP exists, but /root/
	@lxc file push ~/.ssh/id_rsa.pub $(test_container_name)/root/.ssh/authorized_keys --mode=0600 --uid=0

test-lxc-run: container_ip=$(shell lxc list $(test_container_name) --format json | jq -r '.[] .state.network.eth0.addresses[0].address')
test-lxc-run: test-lxc-run-ssh

test-lxc-run-ssh:
	@ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$(container_ip) -C 'uptime'

test: test-lxc-setup test-lxc-run clean-test
	@echo "Tests done"

build:
	$(eval test_container_ip = $$(shell lxc list $(test_container_name) --format json | jq -r ".[] .state.network.eth0.addresses[0].address" ))
	@echo "Container up at IP $(test_container_ip)"

	
