# VPC 모듈의 공통 태그를 위한 로컬 변수 정의
locals {
    vpc_name = var.name

    module_tag = merge(
        var.tags,
        {
            tf_module = "vpc"
            Env = var.attribute.env 
            Team = var.attribute.team 
            VPC = "${local.vpc_name}-vpc"
        }
    )
}

####################
# VPC
####################

locals {
    vpc_cidr = var.attribute.cidr
    # VPC 생성후 VPC ID가 생성됩니다.
    # Terraform에서 locals는 “위에서부터 즉시 실행되는 변수”가 아니라, 
    # Terraform이 전체 코드를 읽고 의존성 그래프를 만든 다음 계산하는 값이기 때문입니다.
    vpc_id = aws_vpc.this.id
}

resource "aws_vpc" "this" {
    cidr_block = local.vpc_cidr
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = merge(
        local.module_tag,
        {
            Name = "${local.vpc_name}-vpc",
        }
    )

}

locals {
    subnets = var.attribute.subnets

    # anytrue()는 리스트 안에 true가 하나라도 있으면 전체 결과를 true로 만드는 함수입니다.
    # 퍼블릭 서브넷이 하나라도 있으면 IGW를 생성합니다. IGW 는 보통 VPC당 하나만 생성합니다.
    enable_igw = anytrue(
        [for k, v in local.subnets : split("-", k)[0] == "pub"]
    )
}

# 퍼블릭 라우트 테이블 생성
resource "aws_route_table" "public" {
    count = local.enable_igw ? 1 : 0
    vpc_id = local.vpc_id

    tags = merge(
        local.module_tag,
        {
            Name = "${local.vpc_name}-rt-pub",
        }
    )
}

####################
# Private Route Table
####################

locals {
    subnet_azs = var.attribute.subnet_azs
}

# 프라이빗 라우트 테이블 AZ별로 생성
resource "aws_route_table" "private" {
    # Terraform 리소스 주소
    # local.subnet_azs = ["a", "c"]
    # 여기서는 for_each가 set이라서 key도 value랑 같습니다.
    # aws_route_table.private["a"]
    # aws_route_table.private["c"]
    for_each = toset(local.subnet_azs)
    vpc_id = local.vpc_id

    tags = merge(
        local.module_tag,
        {
            Name = "${local.vpc_name}-rt-pri-${each.value}",
        }
    )
}

####################
# Subnet
####################

locals {
  # 반복을 수월하게 돌리기 위한 데이터 처리 작업
  # 2차원을 1차원으로 평탄화 필요: 리스트로 flatten 사용
  subnets_data = flatten([
    for name, indices in local.subnets : [ 
      for idx in indices : {
        name      = name
        az        = local.subnet_azs[index(indices, idx)]
        cidr      = cidrsubnet(local.vpc_cidr, local.subnet_newbits, idx)
        is_public = split("-", name)[0] == "pub"
      }
    ]
  ])

  # 실제로 반복에 사용될 변수 생성
  subnets_map = {
    for s in local.subnets_data : "${replace(s.name, "-", "_")}_${s.az}" => s
  }
}

# name = "pub"
# indices = [0, 1, 2]

# name = "pri-app"
# indices = [3, 4, 5]

# name = "pri-db"
# indices = [6, 7, 8]

# > local.subnets_data
# subnets_data = [
#   {
#     name      = "pri-app"
#     az        = "a"
#     cidr      = "10.0.2.0/24"
#     is_public = false
#   },
#   {
#     name      = "pri-app"
#     az        = "c"
#     cidr      = "10.0.3.0/24"
#     is_public = false
#   },

#   {
#     name      = "pri-db"
#     az        = "a"
#     cidr      = "10.0.4.0/24"
#     is_public = false
#   },
#   {
#     name      = "pri-db"
#     az        = "c"
#     cidr      = "10.0.5.0/24"
#     is_public = false
#   },

#   {
#     name      = "pri-msk"
#     az        = "a"
#     cidr      = "10.0.8.0/24"
#     is_public = false
#   },
#   {
#     name      = "pri-msk"
#     az        = "c"
#     cidr      = "10.0.9.0/24"
#     is_public = false
#   },
#   {
#     name      = "pri-msk"
#     az        = "b"
#     cidr      = "10.0.10.0/24"
#     is_public = false
#   },

#   {
#     name      = "pri-network"
#     az        = "a"
#     cidr      = "10.0.6.0/24"
#     is_public = false
#   },
#   {
#     name      = "pri-network"
#     az        = "c"
#     cidr      = "10.0.7.0/24"
#     is_public = false
#   },

#   {
#     name      = "pub-nat"
#     az        = "a"
#     cidr      = "10.0.0.0/24"
#     is_public = true
#   },
#   {
#     name      = "pub-nat"
#     az        = "c"
#     cidr      = "10.0.1.0/24"
#     is_public = true
#   }
# ]

# > local.subnets_map
# local.subnets_map = {
#   pub_nat_a = {
#     name      = "pub-nat"
#     az        = "a"
#     cidr      = "10.0.0.0/24"
#     is_public = true
#   }

#   pub_nat_c = {
#     name      = "pub-nat"
#     az        = "c"
#     cidr      = "10.0.1.0/24"
#     is_public = true
#   }

#   pri_app_a = {
#     name      = "pri-app"
#     az        = "a"
#     cidr      = "10.0.2.0/24"
#     is_public = false
#   }

#   pri_app_c = {
#     name      = "pri-app"
#     az        = "c"
#     cidr      = "10.0.3.0/24"
#     is_public = false
#   }

#   pri_db_a = {
#     name      = "pri-db"
#     az        = "a"
#     cidr      = "10.0.4.0/24"
#     is_public = false
#   }

#   pri_db_c = {
#     name      = "pri-db"
#     az        = "c"
#     cidr      = "10.0.5.0/24"
#     is_public = false
#   }

#   pri_network_a = {
#     name      = "pri-network"
#     az        = "a"
#     cidr      = "10.0.6.0/24"
#     is_public = false
#   }

#   pri_network_c = {
#     name      = "pri-network"
#     az        = "c"
#     cidr      = "10.0.7.0/24"
#     is_public = false
#   }

#   pri_msk_a = {
#     name      = "pri-msk"
#     az        = "a"
#     cidr      = "10.0.8.0/24"
#     is_public = false
#   }

#   pri_msk_c = {
#     name      = "pri-msk"
#     az        = "c"
#     cidr      = "10.0.9.0/24"
#     is_public = false
#   }

#   pri_msk_b = {
#     name      = "pri-msk"
#     az        = "b"
#     cidr      = "10.0.10.0/24"
#     is_public = false
#   }
# }

module "current" {
    source = "../chapter9_utility/1_get_aws_metadata"
    # source = "../utility/get_aws_metadata"
}

locals {
    region_name = module.current.region_name
}

# 서브넷 생성
resource "aws_subnet" "this" {
    for_each = local.subnets_map
    cidr_block = each.value.cidr
    availability_zone = "${local.region_name}${each.value.az}"
    vpc_id = local.vpc_id
    map_public_ip_on_launch = each.value.is_public

    tags = merge(
        local.module_tag,
        {
            Name = "${local.vpc_name}-subnet-${each.value.name}-${each.value.az}"
        }
    )
}

####################
# 서브넷과 라우트 테이블 연결
####################

locals {

}