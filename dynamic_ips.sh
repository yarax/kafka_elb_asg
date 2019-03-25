#!/usr/bin/env bash
sudo -s
yum install -y jq

INSTANCE_LAUNCH_ID=$(curl http://169.254.169.254/latest/meta-data/ami-launch-index)
MY_INST_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

MY_IP=$(aws ec2 --region eu-central-1 describe-instances --instance-ids $MY_INST_ID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

instances=$(aws autoscaling --region eu-central-1 describe-auto-scaling-groups --auto-scaling-group-names KafkaDemoCluster-WebServerGroup)

ZOOKEEPER_NODES=""
ZOOKEEPER_CONNECT=""
COUNTER=1
SERVER_I=0

for inst in $(echo "${instances}" | jq -rc '.AutoScalingGroups[0] | .Instances[]'); do
    INST_ID=$(echo $inst | jq -r '.InstanceId')
    IP=$(aws ec2 --region eu-central-1 describe-instances --instance-ids $INST_ID | jq -rc '.Reservations[0].Instances[0].PublicIpAddress')
    if [ $MY_IP == $IP ]; then
        IP='0.0.0.0'
        SERVER_I=$COUNTER
    fi
    ZOOKEEPER_NODES=$ZOOKEEPER_NODES"server.$COUNTER=$IP:2888:3888"$'\n'
    if [ $COUNTER == 1 ]
    then
        ZOOKEEPER_CONNECT="$IP:2181"
    else
        ZOOKEEPER_CONNECT="$ZOOKEEPER_CONNECT,$IP:2181"
    fi
    COUNTER=$(($COUNTER+1))
done
echo $SERVER_I

echo $ZOOKEEPER_CONNECT
echo $ZOOKEEPER_NODES

rm -rf /tmp/kafka-logs/*

curl "https://raw.githubusercontent.com/ThinkportRepo/kafka_zipkin_demo/master/default_cfg/server.properties.default" > /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp

sed -i "s/broker.id=#BROKER_ID#/$SERVER_I/g" /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp
sed -i "s/#ZOOKEEPER_CONNECT#/$ZOOKEEPER_CONNECT/g" /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp
echo $MY_IP
sed -i "s/#ATVERTISED_LISTENERS#/PLAINTEXT:\/\/$MY_IP:9092/g" /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp
#sed -i "s/zookeeper.connection.timeout.ms=6000/zookeeper.connection.timeout.ms=180000/" /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp
#zookeeper.connection.timeout.ms=6000

cp /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties.default /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties.temp

echo "$ZOOKEEPER_NODES" >> /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties.temp

mv -f /home/ec2-user/kafka_2.11-2.1.0/config/server.properties.temp /home/ec2-user/kafka_2.11-2.1.0/config/server.properties
mv -f /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties.temp /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties

mkdir -p /home/ec2-user/logs
echo $(($SERVER_I)) > /tmp/zookeeper/myid
/home/ec2-user/kafka_2.11-2.1.0/bin/zookeeper-server-start.sh /home/ec2-user/kafka_2.11-2.1.0/config/zookeeper.properties > /home/ec2-user/logs/zookeeper.log 2>&1 &
/home/ec2-user/kafka_2.11-2.1.0/bin/kafka-server-start.sh /home/ec2-user/kafka_2.11-2.1.0/config/server.properties > /home/ec2-user/logs/kafka.log 2>&1 &