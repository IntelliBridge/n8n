# AWS Load Balancer Controller IAM Role
data "aws_iam_openid_connect_provider" "cluster" {
  arn = aws_eks_cluster.flow_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_eks_cluster.flow_cluster.identity[0].oidc[0].issuer
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.flow_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_eks_cluster.flow_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:DescribeSubscription",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# Kubernetes Service Account for AWS Load Balancer Controller
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }

  depends_on = [aws_eks_cluster.flow_cluster]
}

# AWS Load Balancer Controller Helm Chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.flow_cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
  }

  depends_on = [
    aws_eks_node_group.flow_nodes,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}

# Flow Application Namespace
resource "kubernetes_namespace" "flow" {
  metadata {
    name = "flow"
  }

  depends_on = [aws_eks_cluster.flow_cluster]
}

# Flow Application Secrets
resource "kubernetes_secret" "flow_secrets" {
  metadata {
    name      = "flow-secrets"
    namespace = kubernetes_namespace.flow.metadata[0].name
  }

  type = "Opaque"

  data = {
    N8N_ENCRYPTION_KEY    = "NmwxbwHRTVHUhxC4u8YQ0r6UUKzG4VOx"
    OPENSEARCH_HOST       = "https://torqdata:CbEA1twubPUYAaaGde2C!@search-torqdata-datasets-ygg4qepiu7rkr4ry4hxhxzbqjy.aos.us-east-1.on.aws"
    DB_POSTGRESDB_PASSWORD = "C]e5H.bz|NGyd<IJMMaEaArI1V$j"
  }
}

# Flow Application ConfigMap
resource "kubernetes_config_map" "flow_config" {
  metadata {
    name      = "flow-config"
    namespace = kubernetes_namespace.flow.metadata[0].name
  }

  data = {
    N8N_HOST                              = "flow.buildworkforce.ai"
    WEBHOOK_TUNNEL_URL                    = "https://flow.buildworkforce.ai/"
    WEBHOOK_URL                           = "https://flow.buildworkforce.ai/"
    NODE_OPTIONS                          = "--max_old_space_size=8000"
    DB_TYPE                              = "postgresdb"
    DB_POSTGRESDB_HOST                   = "flowdb.cunxsqwqr7rg.us-east-1.rds.amazonaws.com"
    DB_POSTGRESDB_PORT                   = "5432"
    DB_POSTGRESDB_DATABASE               = "flowdb"
    DB_POSTGRESDB_USER                   = "workforce"
    DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED = "false"
    DB_POSTGRESDB_SSL_MODE               = "require"
  }
}

# Flow Application PVC
resource "kubernetes_persistent_volume_claim" "flow_pvc" {
  metadata {
    name      = "flow-pvc"
    namespace = kubernetes_namespace.flow.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp3"

    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}

# Flow Application Deployment
resource "kubernetes_deployment" "flow" {
  metadata {
    name      = "flow"
    namespace = kubernetes_namespace.flow.metadata[0].name
    labels = {
      app = "flow"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "flow"
      }
    }

    template {
      metadata {
        labels = {
          app = "flow"
        }
      }

      spec {
        container {
          image = "${var.ecr_registry}/flow:latest"
          name  = "flow"

          port {
            container_port = 5678
            name          = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.flow_config.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.flow_secrets.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
            limits = {
              memory = "4Gi"
              cpu    = "2000m"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 5678
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 5678
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
          }

          volume_mount {
            name       = "data-volume"
            mount_path = "/home/node/.n8n"
          }
        }

        volume {
          name = "data-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.flow_pvc.metadata[0].name
          }
        }

        restart_policy = "Always"
      }
    }
  }

  depends_on = [
    kubernetes_config_map.flow_config,
    kubernetes_secret.flow_secrets,
    kubernetes_persistent_volume_claim.flow_pvc
  ]
}

# Flow Application Service
resource "kubernetes_service" "flow_service" {
  metadata {
    name      = "flow-service"
    namespace = kubernetes_namespace.flow.metadata[0].name
    labels = {
      app = "flow"
    }
  }

  spec {
    selector = {
      app = "flow"
    }

    port {
      port        = 80
      target_port = 5678
      protocol    = "TCP"
      name        = "http"
    }

    type = "ClusterIP"
  }
}

# Flow Application Ingress
resource "kubernetes_ingress_v1" "flow_ingress" {
  metadata {
    name      = "flow-ingress"
    namespace = kubernetes_namespace.flow.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
      "alb.ingress.kubernetes.io/certificate-arn"      = var.certificate_arn
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/healthz"
    }
  }

  spec {
    rule {
      host = "flow.buildworkforce.ai"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.flow_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    kubernetes_service.flow_service
  ]
}