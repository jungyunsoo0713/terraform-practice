locals {
  info_files = "${path.root}/../info_files" # path.root는 main.tf를 실행하는 디렉터리를 의미합니다. 

  vpc_set = toset([
    for vpcfile in fileset(local.info_files, "*/vpc.yaml") : dirname(vpcfile)
  ])

  env_tags = {
    tf_env = "chapter11_13/env"
  }
}

# fileset은 특정 디렉터리안에서 조건에 맞는 파일 목록을 보여줍니다. 
# *는 local.info_files 바로 아래의 폴더 하나를 의미합니다.
# > fileset(local.info_files, "*/vpc.yaml")
# toset([
#     "vpc-1/vpc.yaml"
#     "vpc-2/vpc.yaml"
# ])

# vpc 이름만 추출
# for_each는 맵 또는 집합 타입의 인수만 받을 수 있기 때문에 사용 불가능
# > [ for vpcfile in fileset(local.info_files, "*/vpc.yaml") : dirname(vpcfile) ] 
# [
#   "vpc-1",
#   "vpc-2",
# ]

# 추출된 VPC 이름 변수는 튜플(리스트) 타입입니다.
# > type([ for vpcfile in fileset(local.info_files, "*/vpc.yaml") : dirname(vpcfile) ])
# tuple([
#     string,
#     string,
# ])

# toset 함수를 사용해서 튜플을 집합을 변환합니다. 
# > toset([
#     for vpcfile in fileset(local.info_files, "*/vpc.yaml") : dirname(vpcfile)
#   ])
# toset([
#   "vpc-1",
#   "vpc-2",
# ])

# info_files 폴더 안에 있는 여러 VPC 설정 파일을 읽어서, VPC 모듈을 여러 번 실행하는 코드야.
module "vpc" {
  for_each = local.vpc_set # e.g. toset(["vpc-1", "vpc-2"])
  # 실제로 VPC를 생성 하는 모듈 코드가 있는 위치
  source = "../modules/chapter11_vpc"

  name = each.key # for_each 때문에 생기는 값으로 each는 현재 반복대상을 의미한다. 
  # 첫 번째 반복에서 each.key는 "vpc-1", 두 번째는 "vpc-2"

  # 현재 VPC 폴더 안에 있는 vpc.yaml 파일을 읽어서 Terraform 값으로 바꾼 다음, attribute라는 변수에 넘기는 코드입니다.
  # yamldecode()는 YAML을 Terraform 값으로 바꿉니다.
  attribute = yamldecode(file("${local.info_files}/${each.key}/vpc.yaml"))
  # attribute는 "../modules/chapter11_vpc" <- 여기서 사용합니다. 
  tags = local.env_tags
}

