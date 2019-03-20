#!/usr/bin/env bash

sudo yum install -y jq

INSTANCE_LAUNCH_ID=$(curl http://169.254.169.254/latest/meta-data/ami-launch-index)

instances=$(aws autoscaling --region eu-central-1 describe-auto-scaling-groups --auto-scaling-group-names KafkaDemoCluster-WebServerGroup)

ZOOKEPER_NODES=""
ZOOKEPER_CONNECT=""
COUNTER=1

for inst in $(echo "${instances}" | jq -rc '.AutoScalingGroups[0] | .Instances[]'); do
    INST_ID=$(echo $inst | jq -r '.InstanceId')
    IP=$(aws ec2 --region eu-central-1 describe-instances --instance-ids $INST_ID | jq -rc '.Reservations[0].Instances[0].PrivateIpAddress')
    ZOOKEPER_NODES=$ZOOKEPER_NODES"server.$COUNTER=$IP:2888:3888"$'\n'
    if [ $COUNTER == 1 ]
    then
        ZOOKEPER_CONNECT="$IP:2181"
    else
        ZOOKEPER_CONNECT="$ZOOKEPER_CONNECT,$IP:2181"
    fi
    COUNTER=$(($COUNTER+1))
done

echo $ZOOKEPER_CONNECT
echo $ZOOKEPER_NODES

sed "s/broker.id=0/broker.id=$INSTANCE_LAUNCH_ID/g" /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.default > /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp
sed -i "s/localhost:2181/$ZOOKEPER_CONNECT/g" /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp

cp /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties.default /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties.temp

echo "$ZOOKEPER_NODES" >> /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties.temp

mv /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp /home/ec2-user/kafka_2.11-2.1.0/config/server.properties
mv /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties.temp /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties

mkdir -p /home/ec2-user/logs

/home/ec2-user/kafka_2.11-2.1.0/bin/zookeeper-server-start.sh /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties > /home/ec2-user/logs/zookeeper.log 2>&1 &
/home/ec2-user/kafka_2.11-2.1.0/bin/kafka-server-start.sh /home/ec2-user/kafka_2.11-2.1.0/config/server.properties > /home/ec2-user/logs/kafka.log 2>&1 &