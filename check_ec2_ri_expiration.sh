#!/bin/bash

# Make sure you have Java and AWS EC2 Tools installed and set as environment variables.
# Check for JAVA_HOME and EC2_HOME with
# echo $JAVA_HOME
# echo $EC2_HOME

RIFILEprod="/tmp/ri_prod$RANDOM.txt"
RIFILEdev="/tmp/ri_dev$RANDOM.txt"
cat /dev/null > $RIFILEprod
cat /dev/null > $RIFILEdev

DAYS=30
OUTPUT="/tmp/ri_output$RANDOM.txt"
cat /dev/null > $OUTPUT

# This function grabs Reserved Instance data from AWS and formats it to make it easier to parse.
# It is designed as a case statement for multiple AWS accounts capabilities.
getRIData() {
    case $1 in
        prod)
            export AWS_ACCESS_KEY="<AWS IAM Access key to query EC2>"
            export AWS_SECRET_KEY="<AWS IAM Secret key to query EC2>"
            "$EC2_HOME"/bin/ec2-describe-reserved-instances --region us-west-2 >> $RIFILEprod
            sed -i "s/(Amazon VPC)//g" $RIFILEprod
            sed -i "/RECURRING-CHARGE/d" $RIFILEprod
            ;;
        dev)
            export AWS_ACCESS_KEY="<AWS IAM Access key to query EC2>"
            export AWS_SECRET_KEY="<AWS IAM Secret key to query EC2>"
            "$EC2_HOME"/bin/ec2-describe-reserved-instances --region us-west-2 >> $RIFILEdev
            sed -i "s/(Amazon VPC)//g" $RIFILEdev
            sed -i "/RECURRING-CHARGE/d" $RIFILEdev
            ;;
    esac
}

# Run the function(s) to grab data.
getRIData prod
getRIData dev

# This function takes the result from getRIData, parses it, and determines if your RIs are within the expiration window or not.
# It is designed as a case statement for multiple AWS accounts capabilities.
checkExpiring() {
    case $1 in
        prod)
            FILE=$RIFILEprod
            RI=$(grep "RESERVEDINSTANCES" $FILE | awk '{print $2}')
            for ri in $(echo $RI); do
                ridate=$(grep $ri $FILE | awk '{print $11}' | cut -d"+" -f1)
                # Mac date version for variable newdate
                # newdate=$(grep $ri $FILE | date -j -f "%Y-%m-%dT%H:%M:%S" -v-30d "$ridate" +%s)
                #
                # Linux date version for variable newdate
                newdate=$(grep $ri $FILE | date -d "$ridate $DAYS days ago" +%s)
                curdate=$(date -u +%s)
                if [[ $curdate -gt $newdate ]]; then
                    echo "WARNING: RI (ID:$ri $(grep $ri $FILE | awk '{print $3,$4,$5,$6,$9}')) expiring on $ridate!" >> $OUTPUT
                else
                    echo "OK: RI ($ri $(grep $ri $FILE | awk '{print $3,$4,$5,"Term:"$6,"Count:",$9}')) does not expire until $ridate." >> $OUTPUT
                fi
            done
        ;;
        dev)
            FILE=$RIFILEdev
            RI=$(grep "RESERVEDINSTANCES" $FILE | awk '{print $2}')
            for ri in $(echo $RI); do
                ridate=$(grep $ri $FILE | awk '{print $11}' | cut -d"+" -f1)
                # Mac date version for variable newdate
                # newdate=$(grep $ri $FILE | date -j -f "%Y-%m-%dT%H:%M:%S" -v-30d "$ridate" +%s)
                #
                # Linux date version for variable newdate
                newdate=$(grep $ri $FILE | date -d "$ridate $DAYS days ago" +%s)
                curdate=$(date -u +%s)
                if [[ $curdate -gt $newdate ]]; then
                    echo "WARNING: RI (ID:$ri $(grep $ri $FILE | awk '{print $3,$4,$5,$6,$9}')) expiring on $ridate!" >> $OUTPUT
                else
                    echo "OK: RI ($ri $(grep $ri $FILE | awk '{print $3,$4,$5,"Term:"$6,"Count:",$9}')) does not expire until $ridate." >> $OUTPUT
                fi
            done
        ;;
    esac
}

# Run the function(s) to parse data.
checkExpiring prod
checkExpiring dev

# Remove temporary files.
rm $RIFILEprod
rm $RIFILEdev

# Statement to determine if any data written to the OUTPUT file contains "WARNING" and if so exit with Warning status.
if [[ $(cat $OUTPUT) =~ "WARNING" ]]; then
    grep "WARNING" $OUTPUT
    rm $OUTPUT
    exit 1
elif [[ ! $(cat $OUTPUT) =~ "WARNING" ]]; then
    echo "OK: No Reserved Instances expiring within $DAYS days."
    rm $OUTPUT
    exit 0
else
    echo "Some sort of error."
    rm $OUTPUT
    exit 3
fi