``` mermaid
flowchart LR;
subgraph Internet 
    subgraph AWS
     style AWS fill:#FF9900
     user
     Route53
     
     listener[ALB listener rules with ssl attached]
     alb[Application Load Balancer]
     subgraph tgA[Target group for application A]
     tgaec2a[EC2-a]
     tgaec2b[EC2-b]
     end
     subgraph tgB[Target group for application B]
     tgbec2a[EC2-a]
     tgbec2b[EC2-b]     
     end
    subgraph acm[Amazon Certificate Manager]
    end
    end
    user -->|http| Route53
    acm --> |ssl| listener
    Route53 -->|http| alb
    alb -->|http| listener
    listener -->|https.subdomain-a| tgA
    listener -->|https.subdomain-b| tgB   
end
```


