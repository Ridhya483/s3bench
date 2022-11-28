# Steps for formatting DAOS
1. Reboot your machine 
2. Check if cluster has stopped 
```
dmg system query -v
```
3. Create run directories 
```
sudo mkdir /var/run/daos_server
sudo mkdir /var/run/daos_agent
```
**If run directories already exist, reboot the machine and try again**

4. Start the daos server 
```
daos_server start &
```
5. Format storage on instance 0
```
dmg storage format
```
6. Start daos agent 
```
dmg_agent &
```
7. Check cluster status
```
dmg system query -v
```
8. Go to ```$CEPH_PATH/build``` and stop ceph
```
../src/stop.sh
```
9. Create daos pool
```
${DAOS_PATH}/install/bin/dmg pool create --size=25GB tank
```
10. Start ceph 
```
RGW=1 ../src/vstart.sh -d
```