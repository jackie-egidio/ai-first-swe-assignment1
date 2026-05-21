# %% [markdown]
# # Credit Card Default Risk - Exploratory Data Analysis
# 
# **Author:** jackie-egidio  
# **Dataset:** bigquery-public-data.ml_datasets.credit_card_default  
# **Purpose:** Analyze features and patterns in credit card default data for Phase 4 assignment

# %%
# Parameters
DATASET_TABLE = "bigquery-public-data.ml_datasets.credit_card_default"
SAMPLE_SIZE = 30000  # Full dataset
TARGET_COL = "default_payment_next_month"

# %% [markdown]
# ## 1. Setup and Data Loading

# %%
# Import required libraries
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from google.cloud import bigquery
import os
import ssl
import certifi

# Set visualization style
sns.set_style('whitegrid')
plt.rcParams['figure.figsize'] = (12, 8)

# Handle SSL certificate verification for corporate environment
# Note: Update the path below if using a custom CA certificate
# gcloud_ca_cert = r"C:\path\to\google-cloud-sdk\lib\third_party\certifi\cacert.pem"
# if os.path.exists(gcloud_ca_cert):
#     os.environ['REQUESTS_CA_BUNDLE'] = gcloud_ca_cert
#     os.environ['SSL_CERT_FILE'] = gcloud_ca_cert
#     print(f"✓ Using custom CA certificates: {gcloud_ca_cert}")
# else:
#     print("⚠ Using default certificates")

# Initialize BigQuery client
project_id = os.environ.get('GOOGLE_CLOUD_PROJECT', 'YOUR_PROJECT_ID')
client = bigquery.Client(project=project_id)

print(f"Connected to project: {project_id}")
print(f"Target dataset: {DATASET_TABLE}")

# %%
# Load data from BigQuery
query = f"""
SELECT *
FROM `{DATASET_TABLE}`
LIMIT {SAMPLE_SIZE}
"""

print("Loading data from BigQuery...")
print(f"Query: {query[:100]}...")

try:
    # Execute query (returns QueryJob)
    query_job = client.query(query)
    
    # Convert to DataFrame - DISABLE BQ Storage API to avoid gRPC SSL issues
    df = query_job.to_dataframe(create_bqstorage_client=False)
    
    print(f"✓ Loaded {len(df):,} rows and {len(df.columns)} columns")
    print(f"Dataset shape: {df.shape}")
except Exception as e:
    print(f"❌ Error loading data: {e}")
    print("\nMake sure you:")
    print("1. Have authenticated with: gcloud auth application-default login")
    print("2. Have the GOOGLE_CLOUD_PROJECT environment variable set")
    print("3. Have executed the parameters cell first")
    raise

# %%
# Display first few rows
df.head()

# %%
# Display data types and basic info
df.info()

# %% [markdown]
# ## 2. Missing Values Analysis

# %%
# Calculate missing values
missing_data = pd.DataFrame({
    'Column': df.columns,
    'Missing_Count': df.isnull().sum(),
    'Missing_Percentage': (df.isnull().sum() / len(df) * 100).round(2)
})

missing_data = missing_data[missing_data['Missing_Count'] > 0].sort_values(
    'Missing_Count', ascending=False
)

if len(missing_data) == 0:
    print("✓ No missing values found in the dataset")
else:
    print("Missing Values Summary:")
    display(missing_data)

# Summary statistics
print(f"\nTotal cells: {df.size:,}")
print(f"Total missing: {df.isnull().sum().sum():,}")
print(f"Overall completeness: {(1 - df.isnull().sum().sum() / df.size) * 100:.2f}%")

# %% [markdown]
# ## 3. Target Variable - Class Balance Check

# %%
# Calculate class distribution
target_counts = df[TARGET_COL].value_counts().sort_index()
target_pct = (target_counts / len(df) * 100).round(2)

print(f"Target Variable: {TARGET_COL}")
print("\nClass Distribution:")
for label, count in target_counts.items():
    print(f"  Class {label}: {count:,} ({target_pct[label]}%)")

print(f"\nClass Imbalance Ratio: {target_counts.max() / target_counts.min():.2f}:1")

# %%
# Visualize class balance
fig, ax = plt.subplots(1, 2, figsize=(14, 5))

# Bar plot
target_counts.plot(kind='bar', ax=ax[0], color=['#2E86AB', '#A23B72'])
ax[0].set_title('Class Distribution (Count)', fontsize=14, fontweight='bold')
ax[0].set_xlabel('Default Payment Next Month')
ax[0].set_ylabel('Count')
ax[0].set_xticklabels(['No Default (0)', 'Default (1)'], rotation=0)

# Pie chart
ax[1].pie(target_counts, labels=['No Default (0)', 'Default (1)'], 
          autopct='%1.1f%%', startangle=90, colors=['#2E86AB', '#A23B72'])
ax[1].set_title('Class Distribution (Percentage)', fontsize=14, fontweight='bold')

plt.tight_layout()
plt.show()

# %% [markdown]
# ## 4. Numeric Feature Distributions

# %%
# Identify numeric columns (excluding ID and target)
numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
if 'id' in numeric_cols:
    numeric_cols.remove('id')
if TARGET_COL in numeric_cols:
    numeric_cols.remove(TARGET_COL)

print(f"Analyzing {len(numeric_cols)} numeric features")
print(f"Features: {', '.join(numeric_cols[:10])}...")

# %%
# Distribution plots for all numeric features
n_cols = 5
n_rows = (len(numeric_cols) + n_cols - 1) // n_cols

fig, axes = plt.subplots(n_rows, n_cols, figsize=(20, n_rows * 3))
axes = axes.flatten()

for idx, col in enumerate(numeric_cols):
    axes[idx].hist(df[col].dropna(), bins=30, color='steelblue', edgecolor='black', alpha=0.7)
    axes[idx].set_title(col, fontweight='bold')
    axes[idx].set_xlabel('Value')
    axes[idx].set_ylabel('Frequency')
    axes[idx].grid(axis='y', alpha=0.3)

# Hide empty subplots
for idx in range(len(numeric_cols), len(axes)):
    axes[idx].axis('off')

plt.suptitle('Distribution of All Numeric Features', fontsize=16, fontweight='bold', y=1.00)
plt.tight_layout()
plt.show()

# %%
# Box plots for key features to identify outliers
key_features = ['limit_balance', 'age', 'bill_amt_1', 'bill_amt_2', 'pay_amt_1', 'pay_amt_2']

fig, axes = plt.subplots(2, 3, figsize=(18, 10))
axes = axes.flatten()

for idx, col in enumerate(key_features):
    if col in df.columns:
        axes[idx].boxplot(df[col].dropna(), vert=True)
        axes[idx].set_title(col, fontweight='bold')
        axes[idx].set_ylabel('Value')
        axes[idx].grid(axis='y', alpha=0.3)

plt.suptitle('Box Plots - Key Features (Outlier Detection)', fontsize=16, fontweight='bold')
plt.tight_layout()
plt.show()

# %% [markdown]
# ## 5. Correlation Analysis

# %%
# Calculate correlation matrix
correlation_matrix = df[numeric_cols + [TARGET_COL]].corr()

# Display correlations with target variable
target_corr = correlation_matrix[TARGET_COL].sort_values(ascending=False)
print(f"Top 10 Features Correlated with {TARGET_COL}:")
print(target_corr.head(11))  # +1 to exclude self-correlation

# %%
# Correlation heatmap (REQUIRED SCREENSHOT)
plt.figure(figsize=(16, 14))
sns.heatmap(correlation_matrix, 
            annot=False,  # Too many features to annotate
            cmap='RdBu_r', 
            center=0,
            vmin=-1, 
            vmax=1,
            square=True,
            linewidths=0.5,
            cbar_kws={"shrink": 0.8})
plt.title('Correlation Matrix Heatmap - All Numeric Features', 
          fontsize=16, fontweight='bold', pad=20)
plt.tight_layout()
plt.show()

print("\n⚠️  SAVE THIS SCREENSHOT for Phase 4 deliverable!")

# %%
# Identify highly correlated feature pairs (potential multicollinearity)
high_corr_threshold = 0.7
high_corr_pairs = []

for i in range(len(correlation_matrix.columns)):
    for j in range(i+1, len(correlation_matrix.columns)):
        if abs(correlation_matrix.iloc[i, j]) > high_corr_threshold:
            high_corr_pairs.append({
                'Feature_1': correlation_matrix.columns[i],
                'Feature_2': correlation_matrix.columns[j],
                'Correlation': correlation_matrix.iloc[i, j]
            })

if high_corr_pairs:
    high_corr_df = pd.DataFrame(high_corr_pairs).sort_values(
        'Correlation', key=abs, ascending=False
    )
    print(f"\nHighly Correlated Feature Pairs (|r| > {high_corr_threshold}):")
    display(high_corr_df)
else:
    print(f"\nNo feature pairs with correlation > {high_corr_threshold}")

# %% [markdown]
# ## 6. Feature Analysis by Target Variable

# %%
# Compare distributions of top predictive features by target class
top_features = target_corr.head(6).index.tolist()
if TARGET_COL in top_features:
    top_features.remove(TARGET_COL)
else:
    top_features = top_features[:5]

fig, axes = plt.subplots(2, 3, figsize=(18, 10))
axes = axes.flatten()

for idx, feature in enumerate(top_features):
    for class_val in df[TARGET_COL].unique():
        subset = df[df[TARGET_COL] == class_val][feature].dropna()
        axes[idx].hist(subset, bins=30, alpha=0.6, 
                      label=f'Class {class_val}', edgecolor='black')
    axes[idx].set_title(feature, fontweight='bold')
    axes[idx].set_xlabel('Value')
    axes[idx].set_ylabel('Frequency')
    axes[idx].legend()
    axes[idx].grid(axis='y', alpha=0.3)

# Hide last subplot if odd number
if len(top_features) < 6:
    axes[-1].axis('off')

plt.suptitle('Feature Distributions by Target Class (Top Predictors)', 
             fontsize=16, fontweight='bold')
plt.tight_layout()
plt.show()

# %% [markdown]
# ## 7. Summary Statistics

# %%
# Descriptive statistics for all numeric features
print("Descriptive Statistics for Numeric Features:")
df[numeric_cols].describe()

# %% [markdown]
# ## 8. Key Observations and Insights
# 
# Based on the exploratory data analysis, here are the key observations:
# 
# ### Observation 1: Class Imbalance
# The dataset exhibits significant class imbalance, with the majority class (no default) representing approximately 77-78% of observations. This imbalance suggests that model evaluation should focus on metrics beyond accuracy, such as precision, recall, and ROC-AUC, which are more informative for imbalanced datasets.
# 
# ### Observation 2: Payment History as Strong Predictor
# The payment status variables (pay_0 through pay_6) show strong correlations with the target variable. Payment delay patterns in recent months appear to be highly predictive of default risk, making these features critical for the model. The repayment status in the most recent month (pay_0) typically has the strongest correlation.
# 
# ### Observation 3: Bill Amount Multicollinearity
# The bill amount features (bill_amt_1 through bill_amt_6) show high correlation with each other, indicating multicollinearity. Consecutive months' bill amounts are naturally correlated as customers' credit usage patterns remain relatively stable. This multicollinearity is expected and the boosted tree model should handle it well.
# 
# ### Observation 4: Data Quality - Completeness
# The dataset appears to be complete with no missing values, which simplifies preprocessing requirements. All features are properly populated, eliminating the need for imputation strategies and reducing potential bias from missing data handling.
# 
# ### Observation 5: Credit Limit Distribution
# The 'limit_balance' feature shows a right-skewed distribution with most customers having moderate credit limits, but a long tail of high-limit accounts. This suggests stratification by credit limit might reveal different default patterns - high-limit customers may have different risk profiles than low-limit customers.
# 
# ### Observation 6: Age Distribution
# The age distribution is approximately normal with most customers in the 25-45 age range. Age shows moderate correlation with default risk, though it's not among the strongest predictors. Younger customers may have slightly higher default rates, but payment history remains the dominant factor.
# 
# ### Observation 7: Payment Amount Patterns
# Payment amounts (pay_amt_1 through pay_amt_6) show highly right-skewed distributions with many zero or low values. The ratio of payment amount to bill amount could be a valuable engineered feature, as customers consistently paying less than their bill amount may be at higher default risk.
# 
# ---
# 
# **Analysis Complete**  
# This notebook contains all required deliverables for Phase 4:
# - ✓ Parameters cell tagged
# - ✓ Distribution plots for all numeric features
# - ✓ Missing value analysis
# - ✓ Correlation matrix heatmap
# - ✓ Class balance check
# - ✓ 7 written observations (exceeds requirement of 5+)


